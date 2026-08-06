#import "RubyRuntimeMacosPlugin.h"

#include <mach/mach_time.h>
#include <stdlib.h>

#include "ruflet_vm_host.h"

// Flutter bridge for the embedded Ruby VM.
//
// The VM itself -- the mruby interpreter, the bootstrap providing
// require/$LOAD_PATH/ENV, and the entrypoint runner -- lives in the prebuilt
// RufletVM library behind four C entry points. Every platform bridges to those
// same entry points, so releasing a runtime means replacing the built artifact
// and nothing else; there is no host logic to keep in step across plugins.

// Earliest point this plugin can observe: +load runs when the dylib is loaded,
// before UIApplicationMain and before the Flutter engine exists. Everything
// between here and the first `start` call is prologue the VM currently sits
// idle through, so recording it answers how much a platform-side start could
// actually overlap. Reported to Dart through the `timeline` method.
static uint64_t g_load_ticks = 0;
static mach_timebase_info_data_t g_timebase = {0, 0};

static double ms_since_load(void) {
  if (g_load_ticks == 0 || g_timebase.denom == 0) {
    return -1.0;
  }
  const uint64_t elapsed = mach_absolute_time() - g_load_ticks;
  return (double)elapsed * (double)g_timebase.numer /
         (double)g_timebase.denom / 1000000.0;
}

// Autostart state. The VM boots on a background queue from +load, long before
// Dart can ask for it, so the answer to `serverUrl` is usually already here by
// the time the first method call arrives.
static NSString *g_server_url = nil;
static NSString *g_autostart_error = nil;
static NSCondition *g_autostart_signal = nil;
static BOOL g_autostart_attempted = NO;

// Where `flutter build` puts the asset bundle inside a macOS app. Native code
// can read these directly -- they are ordinary files on disk -- which is why
// autostart does not need to copy the project anywhere first.
static NSString *flutter_assets_dir(void) {
  NSString *resources = [[NSBundle mainBundle] privateFrameworksPath];
  if (resources == nil) {
    return nil;
  }
  return [resources
      stringByAppendingPathComponent:@"App.framework/Resources/flutter_assets"];
}

// The packaged project is the single directory under flutter_assets/assets
// holding a main.rb. RufletEmbeddedProject in Info.plist names it explicitly
// when an app packages more than one.
static NSString *packaged_project_root(void) {
  NSString *assets = flutter_assets_dir();
  if (assets == nil) {
    return nil;
  }
  NSString *root = [assets stringByAppendingPathComponent:@"assets"];
  NSFileManager *files = [NSFileManager defaultManager];

  NSString *configured = [[NSBundle mainBundle]
      objectForInfoDictionaryKey:@"RufletEmbeddedProject"];
  if ([configured isKindOfClass:[NSString class]] && configured.length > 0) {
    NSString *candidate = [root stringByAppendingPathComponent:configured];
    return [files fileExistsAtPath:[candidate
                                       stringByAppendingPathComponent:@"main.rb"]]
               ? candidate
               : nil;
  }

  NSArray<NSString *> *entries = [files contentsOfDirectoryAtPath:root error:nil];
  NSString *found = nil;
  for (NSString *entry in entries) {
    NSString *candidate = [root stringByAppendingPathComponent:entry];
    if (![files fileExistsAtPath:[candidate
                                     stringByAppendingPathComponent:@"main.rb"]]) {
      continue;
    }
    if (found != nil) {
      return nil; // Ambiguous; the app must name one in Info.plist.
    }
    found = candidate;
  }
  return found;
}

static void finish_autostart(NSString *url, NSString *error) {
  [g_autostart_signal lock];
  g_server_url = url;
  g_autostart_error = error;
  [g_autostart_signal broadcast];
  [g_autostart_signal unlock];
}

static void begin_autostart(void) {
  NSString *root = packaged_project_root();
  if (root == nil) {
    finish_autostart(nil, @"No packaged Ruby project found in the app bundle.");
    return;
  }

  // The bundle is read-only, so the runtime's scratch files live in the app's
  // temporary directory rather than beside the sources.
  NSString *scratch = [NSTemporaryDirectory()
      stringByAppendingPathComponent:@"ruflet-runtime"];
  [[NSFileManager defaultManager] createDirectoryAtPath:scratch
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  NSString *portPath = [scratch stringByAppendingPathComponent:@"server.port"];
  NSString *errorPath = [scratch stringByAppendingPathComponent:@"server.error"];
  NSString *stopPath = [scratch stringByAppendingPathComponent:@"server.stop"];
  [[NSFileManager defaultManager] removeItemAtPath:portPath error:nil];
  [[NSFileManager defaultManager] removeItemAtPath:errorPath error:nil];

  NSString *entrypoint = [root stringByAppendingPathComponent:@"main.rb"];
  NSString *assetsDir = [root stringByAppendingPathComponent:@"assets"];

  const char *loadPaths[] = {root.UTF8String};
  const char *environmentKeys[] = {"RUFLET_PORT", "RUFLET_ASSETS_DIR",
                                   "RUFLET_RUNTIME_PORT_FILE",
                                   "RUFLET_RUNTIME_ERROR_FILE",
                                   "RUFLET_SUPPRESS_SERVER_BANNER"};
  const char *environmentValues[] = {"0", assetsDir.UTF8String,
                                     portPath.UTF8String, errorPath.UTF8String,
                                     "1"};

  const int status = ruflet_vm_start(
      root.UTF8String, entrypoint.UTF8String, loadPaths, 1, environmentKeys,
      environmentValues, 5, stopPath.UTF8String, errorPath.UTF8String);
  if (status != 0) {
    finish_autostart(nil, @"Embedded entrypoint was rejected by the VM.");
    return;
  }

  // Poll for the port the Ruby server publishes. Tight, because this runs off
  // the main thread and the whole point is to have an answer ready early.
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:30.0];
  while ([deadline timeIntervalSinceNow] > 0) {
    NSString *published =
        [NSString stringWithContentsOfFile:portPath
                                  encoding:NSUTF8StringEncoding
                                     error:nil];
    const int port = published == nil ? 0 : published.intValue;
    if (port > 0) {
      finish_autostart(
          [NSString stringWithFormat:@"http://127.0.0.1:%d", port], nil);
      return;
    }
    NSString *failure =
        [NSString stringWithContentsOfFile:errorPath
                                  encoding:NSUTF8StringEncoding
                                     error:nil];
    if (failure.length > 0) {
      finish_autostart(nil, failure);
      return;
    }
    usleep(1000);
  }
  finish_autostart(nil, @"Embedded Ruflet server did not publish a port.");
}

@implementation RubyRuntimeMacosPlugin

+ (void)load {
  mach_timebase_info(&g_timebase);
  g_load_ticks = mach_absolute_time();
  g_autostart_signal = [[NSCondition alloc] init];

  // Opt-in: a server-driven app has no packaged project and must not boot a
  // second VM, and an app that wants to configure the runtime from Dart still
  // can. Autostart only happens when the app asks for it.
  NSNumber *enabled =
      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"RufletRuntimeAutostart"];
  if (![enabled isKindOfClass:[NSNumber class]] || !enabled.boolValue) {
    return;
  }

  g_autostart_attempted = YES;
  // Off the main thread: +load runs during dylib loading and anything slow
  // here delays the whole app, which would trade the win away.
  dispatch_async(
      dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        begin_autostart();
      });
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
    // The VM boots once per process. When autostart owns it, a start() call
    // cannot take effect: ruflet_vm_start sees a running VM and returns
    // success without adopting any of the arguments, so the runtime keeps
    // writing to the paths autostart chose and the caller waits forever on a
    // port file nothing will write. Say so instead of reporting success.
    if (g_autostart_attempted) {
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

  if ([call.method isEqualToString:@"status"]) {
    result(runtime_status());
    return;
  }

  // Milliseconds since the plugin's dylib was loaded. Lets Dart place its own
  // timestamps on a timeline that starts before the engine did.
  if ([call.method isEqualToString:@"timeline"]) {
    result(@{@"sinceLoadMs" : [NSNumber numberWithDouble:ms_since_load()]});
    return;
  }

  // The URL of the autostarted server. Returns as soon as the platform side
  // knows it -- immediately when the VM finished booting during engine startup,
  // otherwise when it does. Answering blocks a background queue, never the
  // platform thread.
  if ([call.method isEqualToString:@"serverUrl"]) {
    if (!g_autostart_attempted) {
      result([FlutterError errorWithCode:@"autostart_disabled"
                                 message:@"Set RufletRuntimeAutostart in "
                                         @"Info.plist to use serverUrl()."
                                 details:nil]);
      return;
    }
    dispatch_async(
        dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
          [g_autostart_signal lock];
          while (g_server_url == nil && g_autostart_error == nil) {
            [g_autostart_signal wait];
          }
          NSString *url = g_server_url;
          NSString *failure = g_autostart_error;
          [g_autostart_signal unlock];

          dispatch_async(dispatch_get_main_queue(), ^{
            if (url != nil) {
              result(@{@"url" : url});
            } else {
              result([FlutterError errorWithCode:@"ruflet_runtime_error"
                                         message:failure
                                         details:nil]);
            }
          });
        });
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
