#import "RubyRuntimeMacosPlugin.h"

#include <mruby.h>
#include <mruby/irep.h>
#include <mruby/string.h>
#include <mruby/variable.h>
#include <stdlib.h>

#include "../../../shared/embedded_ruflet_runtime.h"

@implementation RubyRuntimeMacosPlugin

static const int kRufletServerPort = 8550;
static mrb_state *g_mrb = NULL;
static NSLock *g_vm_lock = nil;
static BOOL g_server_running = NO;
static BOOL g_runtime_loaded = NO;
static NSString *g_stop_signal_path = nil;
static NSString *g_runtime_error_path = nil;
static NSString *g_last_server_error = nil;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"ruflet_runtime"
                                  binaryMessenger:[registrar messenger]];
  RubyRuntimeMacosPlugin *instance = [[RubyRuntimeMacosPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
  self = [super init];
  if (self != nil && g_vm_lock == nil) {
    g_vm_lock = [[NSLock alloc] init];
  }
  return self;
}

static NSString *exception_to_string(mrb_state *mrb) {
  if (mrb == NULL || mrb->exc == NULL) {
    return @"unknown mruby error";
  }

  mrb_value exception = mrb_obj_value(mrb->exc);
  const char *class_name = mrb_obj_classname(mrb, exception);
  mrb_value message = mrb_funcall(mrb, exception, "to_s", 0);
  if (mrb->exc != NULL) {
    mrb->exc = NULL;
    return @"failed to render mruby exception";
  }

  const char *text = mrb_string_value_cstr(mrb, &message);
  NSString *klass = class_name == NULL
      ? @"Exception"
      : ([NSString stringWithUTF8String:class_name] ?: @"Exception");
  NSString *detail =
      text == NULL ? @"<empty>" : ([NSString stringWithUTF8String:text] ?: @"<invalid utf8>");
  mrb->exc = NULL;
  return [NSString stringWithFormat:@"%@: %@", klass, detail];
}

static BOOL preload_ruflet_runtime(mrb_state *mrb, NSError **error) {
  if (g_runtime_loaded) {
    return YES;
  }

  mrb_load_irep(mrb, kEmbeddedRufletRuntimeIrep);
  if (mrb->exc != NULL) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"ruflet_runtime"
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey : exception_to_string(mrb)}];
    }
    return NO;
  }

  g_runtime_loaded = YES;
  return YES;
}

static NSDictionary<NSString *, id> *runtime_status(void) {
  NSString *reported_error = g_runtime_error_path.length == 0
      ? nil
      : [NSString stringWithContentsOfFile:g_runtime_error_path
                                  encoding:NSUTF8StringEncoding
                                     error:nil];
  return @{
    @"running" : @(g_server_running),
    @"port" : @(g_server_running ? kRufletServerPort : 0),
    @"error" : reported_error ?: g_last_server_error ?: @""
  };
}

static void request_stop(void) {
  if (g_stop_signal_path.length == 0) {
    return;
  }
  [@"stop" writeToFile:g_stop_signal_path
            atomically:YES
              encoding:NSUTF8StringEncoding
                 error:nil];
}

static BOOL valid_entrypoint(NSString *project_root, NSString *entrypoint) {
  if (project_root.length == 0 || entrypoint.length == 0) {
    return NO;
  }
  NSString *root = project_root.stringByStandardizingPath;
  NSString *path = entrypoint.stringByStandardizingPath;
  NSString *prefix = [root stringByAppendingString:@"/"];
  return [path.pathExtension.lowercaseString isEqualToString:@"mrb"] &&
         ([path isEqualToString:root] || [path hasPrefix:prefix]);
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"start"]) {
    NSDictionary *arguments = (NSDictionary *)call.arguments;
    NSString *project_root = arguments[@"projectRoot"];
    NSString *entrypoint = arguments[@"entrypoint"];
    if (![project_root isKindOfClass:[NSString class]] ||
        ![entrypoint isKindOfClass:[NSString class]] ||
        !valid_entrypoint(project_root, entrypoint)) {
      result([FlutterError errorWithCode:@"invalid_args"
                                 message:@"Ruflet requires a .mrb entrypoint inside projectRoot."
                                 details:nil]);
      return;
    }

    if (g_server_running) {
      result(runtime_status());
      return;
    }

    NSError *read_error = nil;
    NSData *bytecode = [NSData dataWithContentsOfFile:entrypoint options:0 error:&read_error];
    if (bytecode == nil || bytecode.length == 0) {
      result([FlutterError errorWithCode:@"ruflet_start_error"
                                 message:read_error.localizedDescription ?: @"Unable to read Ruflet entrypoint."
                                 details:nil]);
      return;
    }

    NSString *stop_path = arguments[@"stopSignalPath"];
    if (![stop_path isKindOfClass:[NSString class]] || stop_path.length == 0) {
      stop_path = [project_root stringByAppendingPathComponent:@".ruflet-server.stop"];
    }
    [[NSFileManager defaultManager] removeItemAtPath:stop_path error:nil];
    NSString *runtime_error_path =
        [project_root stringByAppendingPathComponent:@".ruflet-runtime.error"];
    [[NSFileManager defaultManager] removeItemAtPath:runtime_error_path error:nil];

    g_stop_signal_path = stop_path;
    g_runtime_error_path = runtime_error_path;
    g_last_server_error = nil;
    g_server_running = YES;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      setenv("RUFLET_PROD_STOP_FILE", stop_path.UTF8String, 1);
      setenv("RUFLET_STRICT_PORT", "1", 1);
      setenv("RUFLET_RUNTIME_ERROR_FILE", runtime_error_path.UTF8String, 1);

      [g_vm_lock lock];
      if (g_mrb != NULL) {
        mrb_close(g_mrb);
      }
      g_mrb = mrb_open();
      g_runtime_loaded = NO;

      NSError *runtime_error = nil;
      if (g_mrb == NULL) {
        runtime_error = [NSError errorWithDomain:@"ruflet_runtime"
                                            code:2
                                        userInfo:@{NSLocalizedDescriptionKey : @"Unable to initialize mruby."}];
      } else if (preload_ruflet_runtime(g_mrb, &runtime_error)) {
        mrb_sym root_symbol = mrb_intern_lit(g_mrb, "$__ruflet_app_root");
        mrb_gv_set(g_mrb, root_symbol, mrb_str_new_cstr(g_mrb, project_root.UTF8String));
        mrb_sym error_path_symbol = mrb_intern_lit(g_mrb, "$__ruflet_runtime_error_file");
        mrb_gv_set(g_mrb, error_path_symbol,
                   mrb_str_new_cstr(g_mrb, runtime_error_path.UTF8String));
        mrb_load_irep_buf(g_mrb, bytecode.bytes, bytecode.length);
        if (g_mrb->exc != NULL) {
          runtime_error = [NSError errorWithDomain:@"ruflet_runtime"
                                              code:3
                                          userInfo:@{NSLocalizedDescriptionKey : exception_to_string(g_mrb)}];
        }
      }

      BOOL stopped = [[NSFileManager defaultManager] fileExistsAtPath:stop_path];
      if (runtime_error != nil) {
        g_last_server_error = runtime_error.localizedDescription;
        NSLog(@"[ruflet_runtime] %@", g_last_server_error);
      } else if (!stopped) {
        g_last_server_error = @"Ruflet server exited unexpectedly.";
        NSLog(@"[ruflet_runtime] %@", g_last_server_error);
      }

      if (g_mrb != NULL) {
        mrb_close(g_mrb);
        g_mrb = NULL;
      }
      g_runtime_loaded = NO;
      [g_vm_lock unlock];
      g_server_running = NO;
    });

    result(runtime_status());
    return;
  }

  if ([call.method isEqualToString:@"status"]) {
    result(runtime_status());
    return;
  }

  if ([call.method isEqualToString:@"stop"]) {
    request_stop();
    result(nil);
    return;
  }

  result(FlutterMethodNotImplemented);
}

@end
