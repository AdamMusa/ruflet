#import <Flutter/Flutter.h>
#import <Foundation/Foundation.h>

#include <mruby.h>
#include <mruby/array.h>
#include <mruby/compile.h>
#include <mruby/irep.h>
#include <mruby/string.h>
#include <mruby/variable.h>
#include <stdlib.h>

#include "vm_bootstrap.h"

// Generic embedded Ruby VM host. It provides the mruby interpreter, the
// bootstrap (require/$LOAD_PATH/ENV machinery), and three native primitives
// the bootstrap needs. It knows nothing about the app framework: gems and
// application code are plain files under the project root, loaded through
// the bootstrap's require machinery.

@interface MrubyRuntimePlugin : NSObject <FlutterPlugin>
@end

@implementation MrubyRuntimePlugin

static mrb_state *g_mrb = NULL;
static NSLock *g_vm_lock = nil;
static BOOL g_app_running = NO;
static NSString *g_stop_signal_path = nil;
static NSString *g_error_file_path = nil;
static NSString *g_last_error = nil;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"ruflet_runtime"
                                  binaryMessenger:[registrar messenger]];
  MrubyRuntimePlugin *instance = [[MrubyRuntimePlugin alloc] init];
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

  mrb_print_backtrace(mrb);
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

static void reraise_pending(mrb_state *mrb) {
  if (mrb->exc != NULL) {
    mrb_value exc = mrb_obj_value(mrb->exc);
    mrb->exc = NULL;
    mrb_exc_raise(mrb, exc);
  }
}

// RubyRuntime.__eval(source, filename) -- top-level eval with file context.
static mrb_value rr_eval(mrb_state *mrb, mrb_value self) {
  (void)self;
  mrb_value source;
  mrb_value filename = mrb_nil_value();
  mrb_get_args(mrb, "S|S", &source, &filename);

  mrbc_context *cxt = mrbc_context_new(mrb);
  cxt->capture_errors = TRUE;
  if (mrb_string_p(filename)) {
    mrbc_filename(mrb, cxt, mrb_string_value_cstr(mrb, &filename));
  }
  mrb_value result = mrb_load_nstring_cxt(mrb, RSTRING_PTR(source), RSTRING_LEN(source), cxt);
  mrbc_context_free(mrb, cxt);
  reraise_pending(mrb);
  return result;
}

// RubyRuntime.__load_irep(bytes) -- run precompiled .mrb bytecode.
static mrb_value rr_load_irep(mrb_state *mrb, mrb_value self) {
  (void)self;
  mrb_value bytes;
  mrb_get_args(mrb, "S", &bytes);

  mrb_value result =
      mrb_load_irep_buf(mrb, (const uint8_t *)RSTRING_PTR(bytes), RSTRING_LEN(bytes));
  reraise_pending(mrb);
  return result;
}

// RubyRuntime.__getenv(name) -- read the process environment.
static mrb_value rr_getenv(mrb_state *mrb, mrb_value self) {
  (void)self;
  mrb_value name;
  mrb_get_args(mrb, "S", &name);

  const char *value = getenv(mrb_string_value_cstr(mrb, &name));
  if (value == NULL) {
    return mrb_nil_value();
  }
  return mrb_str_new_cstr(mrb, value);
}

static void register_native_primitives(mrb_state *mrb) {
  struct RClass *runtime = mrb_define_module(mrb, "RubyRuntime");
  mrb_define_module_function(mrb, runtime, "__eval", rr_eval, MRB_ARGS_ARG(1, 1));
  mrb_define_module_function(mrb, runtime, "__load_irep", rr_load_irep, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, runtime, "__getenv", rr_getenv, MRB_ARGS_REQ(1));
}

static NSDictionary<NSString *, id> *runtime_status(void) {
  NSString *reported_error = g_error_file_path.length == 0
      ? nil
      : [NSString stringWithContentsOfFile:g_error_file_path
                                  encoding:NSUTF8StringEncoding
                                     error:nil];
  return @{
    @"running" : @(g_app_running),
    @"error" : reported_error ?: g_last_error ?: @""
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
  NSString *ext = path.pathExtension.lowercaseString;
  BOOL supported = [ext isEqualToString:@"rb"] || [ext isEqualToString:@"mrb"];
  return supported && ([path isEqualToString:root] || [path hasPrefix:prefix]);
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
                                 message:@"start requires a .rb or .mrb entrypoint inside projectRoot."
                                 details:nil]);
      return;
    }

    if (g_app_running) {
      result(runtime_status());
      return;
    }

    NSArray *load_paths_arg = [arguments[@"loadPaths"] isKindOfClass:[NSArray class]]
        ? arguments[@"loadPaths"]
        : @[];
    NSMutableArray<NSString *> *load_paths = [NSMutableArray array];
    for (id entry in load_paths_arg) {
      if ([entry isKindOfClass:[NSString class]]) {
        [load_paths addObject:entry];
      }
    }

    NSDictionary *environment = [arguments[@"environment"] isKindOfClass:[NSDictionary class]]
        ? arguments[@"environment"]
        : @{};

    NSString *stop_path = arguments[@"stopSignalPath"];
    if (![stop_path isKindOfClass:[NSString class]] || stop_path.length == 0) {
      stop_path = [project_root stringByAppendingPathComponent:@".runtime.stop"];
    }
    [[NSFileManager defaultManager] removeItemAtPath:stop_path error:nil];

    NSString *error_file = arguments[@"errorFilePath"];
    if (![error_file isKindOfClass:[NSString class]]) {
      error_file = @"";
    }
    if (error_file.length > 0) {
      [[NSFileManager defaultManager] removeItemAtPath:error_file error:nil];
    }

    g_stop_signal_path = stop_path;
    g_error_file_path = error_file;
    g_last_error = nil;
    g_app_running = YES;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      for (NSString *key in environment) {
        id value = environment[key];
        if ([value isKindOfClass:[NSString class]]) {
          setenv(key.UTF8String, ((NSString *)value).UTF8String, 1);
        }
      }

      [g_vm_lock lock];
      if (g_mrb != NULL) {
        mrb_close(g_mrb);
      }
      g_mrb = mrb_open();

      NSError *runtime_error = nil;
      if (g_mrb == NULL) {
        runtime_error = [NSError errorWithDomain:@"ruby_runtime"
                                            code:2
                                        userInfo:@{NSLocalizedDescriptionKey : @"Unable to initialize mruby."}];
      } else {
        register_native_primitives(g_mrb);
        mrb_load_irep(g_mrb, kRubyRuntimeVmBootstrapIrep);
        if (g_mrb->exc != NULL) {
          runtime_error = [NSError errorWithDomain:@"ruby_runtime"
                                              code:1
                                          userInfo:@{NSLocalizedDescriptionKey : exception_to_string(g_mrb)}];
        } else {
          struct RClass *runtime = mrb_module_get(g_mrb, "RubyRuntime");
          mrb_value paths = mrb_ary_new_capa(g_mrb, (mrb_int)load_paths.count);
          for (NSString *path in load_paths) {
            mrb_ary_push(g_mrb, paths, mrb_str_new_cstr(g_mrb, path.UTF8String));
          }
          mrb_funcall(g_mrb, mrb_obj_value(runtime), "boot", 3,
                      mrb_str_new_cstr(g_mrb, project_root.UTF8String),
                      mrb_str_new_cstr(g_mrb, entrypoint.UTF8String),
                      paths);
          if (g_mrb->exc != NULL) {
            runtime_error = [NSError errorWithDomain:@"ruby_runtime"
                                                code:3
                                            userInfo:@{NSLocalizedDescriptionKey : exception_to_string(g_mrb)}];
          }
        }
      }

      BOOL stopped = [[NSFileManager defaultManager] fileExistsAtPath:stop_path];
      if (runtime_error != nil) {
        g_last_error = runtime_error.localizedDescription;
        NSLog(@"[ruby_runtime] %@", g_last_error);
      } else if (!stopped) {
        g_last_error = @"Embedded Ruby app exited unexpectedly.";
        NSLog(@"[ruby_runtime] %@", g_last_error);
      }

      if (g_mrb != NULL) {
        mrb_close(g_mrb);
        g_mrb = NULL;
      }
      [g_vm_lock unlock];
      g_app_running = NO;
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
