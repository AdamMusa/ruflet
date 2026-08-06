#import "RubyRuntimeMacosPlugin.h"

#include <stdlib.h>

#include "ruflet_runtime_autostart.h"
#include "ruflet_vm_host.h"

// Flutter bridge for the embedded Ruby VM.
//
// The VM itself -- the mruby interpreter, the bootstrap providing
// require/$LOAD_PATH/ENV, and the entrypoint runner -- lives in the prebuilt
// RufletVM library behind four C entry points. Every platform bridges to those
// same entry points, so releasing a runtime means replacing the built artifact
// and nothing else; there is no host logic to keep in step across plugins.
//
// Startup itself is shared with iOS in apple/ruflet_runtime_autostart.h.

@implementation RubyRuntimeMacosPlugin

+ (void)load {
  ruflet_autostart_on_load();
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"ruflet_runtime"
                                  binaryMessenger:[registrar messenger]];
  RubyRuntimeMacosPlugin *instance = [[RubyRuntimeMacosPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

static NSString *runtime_error(void) {
  const size_t size = ruflet_vm_copy_error(NULL, 0);
  if (size == 0) {
    return @"";
  }
  char *buffer = (char *)calloc(size, sizeof(char));
  if (buffer == NULL) {
    return @"";
  }
  ruflet_vm_copy_error(buffer, size);
  NSString *message = [NSString stringWithUTF8String:buffer] ?: @"";
  free(buffer);
  return message;
}

static NSDictionary *runtime_status(void) {
  // Dart reads this as `value['running'] == true`, so it has to arrive as a
  // boolean. ruflet_vm_is_running() returns int, and boxing a C comparison
  // with @() yields numberWithInt -- Dart would then see 1, and `1 == true`
  // is false, reporting a healthy VM as stopped.
  return @{
    @"running" : [NSNumber numberWithBool:(ruflet_vm_is_running() != 0)],
    @"error" : runtime_error()
  };
}

static NSArray<NSString *> *string_list(id value) {
  NSMutableArray<NSString *> *values = [NSMutableArray array];
  if ([value isKindOfClass:[NSArray class]]) {
    for (id entry in (NSArray *)value) {
      if ([entry isKindOfClass:[NSString class]]) {
        [values addObject:entry];
      }
    }
  }
  return values;
}

static NSString *string_argument(NSDictionary *arguments, NSString *key) {
  id value = arguments[key];
  return [value isKindOfClass:[NSString class]] ? (NSString *)value : @"";
}

// Borrows UTF-8 pointers for a list of strings. The pointers reference the
// NSData buffers appended to `storage`, which must outlive the call.
static const char **borrow_utf8(NSArray<NSString *> *values,
                                NSMutableArray *storage) {
  if (values.count == 0) {
    return NULL;
  }
  const char **pointers = (const char **)calloc(values.count, sizeof(char *));
  if (pointers == NULL) {
    return NULL;
  }
  NSUInteger index = 0;
  for (NSString *value in values) {
    NSData *utf8 = [value dataUsingEncoding:NSUTF8StringEncoding];
    [storage addObject:utf8];
    pointers[index++] = (const char *)utf8.bytes;
  }
  return pointers;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"start"]) {
    if (ruflet_autostart_owns_runtime()) {
      result([FlutterError
          errorWithCode:@"autostart_owns_runtime"
                message:@"The platform already started the runtime "
                        @"(RufletRuntimeAutostart). Use serverUrl() instead of "
                        @"start(), or turn autostart off."
                details:nil]);
      return;
    }

    NSDictionary *arguments = [call.arguments isKindOfClass:[NSDictionary class]]
                                  ? (NSDictionary *)call.arguments
                                  : @{};
    NSString *projectRoot = string_argument(arguments, @"projectRoot");
    NSString *entrypoint = string_argument(arguments, @"entrypoint");
    NSString *stopPath = string_argument(arguments, @"stopSignalPath");
    NSString *errorPath = string_argument(arguments, @"errorFilePath");
    NSArray<NSString *> *loadPaths = string_list(arguments[@"loadPaths"]);

    NSMutableArray<NSString *> *environmentKeys = [NSMutableArray array];
    NSMutableArray<NSString *> *environmentValues = [NSMutableArray array];
    if ([arguments[@"environment"] isKindOfClass:[NSDictionary class]]) {
      NSDictionary *environment = (NSDictionary *)arguments[@"environment"];
      for (id key in environment) {
        id value = environment[key];
        if ([key isKindOfClass:[NSString class]] &&
            [value isKindOfClass:[NSString class]]) {
          [environmentKeys addObject:key];
          [environmentValues addObject:value];
        }
      }
    }

    NSMutableArray *storage = [NSMutableArray array];
    const char **loadPathPointers = borrow_utf8(loadPaths, storage);
    const char **environmentKeyPointers = borrow_utf8(environmentKeys, storage);
    const char **environmentValuePointers =
        borrow_utf8(environmentValues, storage);

    const int status = ruflet_vm_start(
        projectRoot.UTF8String, entrypoint.UTF8String, loadPathPointers,
        loadPaths.count, environmentKeyPointers, environmentValuePointers,
        environmentKeys.count, stopPath.UTF8String, errorPath.UTF8String);

    free(loadPathPointers);
    free(environmentKeyPointers);
    free(environmentValuePointers);

    if (status != 0) {
      result([FlutterError
          errorWithCode:@"invalid_args"
                message:
                    @"start requires a .rb or .mrb entrypoint inside projectRoot."
                details:nil]);
      return;
    }
    result(runtime_status());
    return;
  }

  if ([call.method isEqualToString:@"serverUrl"]) {
    ruflet_autostart_resolve_url(result);
    return;
  }

  if ([call.method isEqualToString:@"status"]) {
    result(runtime_status());
    return;
  }

  // Milliseconds since the plugin's dylib was loaded. Lets Dart place its own
  // timestamps on a timeline that starts before the engine did.
  if ([call.method isEqualToString:@"timeline"]) {
    result(@{@"sinceLoadMs" : [NSNumber numberWithDouble:ruflet_ms_since_load()]});
    return;
  }

  if ([call.method isEqualToString:@"stop"]) {
    ruflet_vm_stop();
    result(nil);
    return;
  }

  result(FlutterMethodNotImplemented);
}

@end
