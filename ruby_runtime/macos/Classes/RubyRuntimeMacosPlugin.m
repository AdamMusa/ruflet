#import "RubyRuntimeMacosPlugin.h"

#include <mruby.h>
#include <mruby/array.h>
#include <mruby/compile.h>
#include <mruby/irep.h>
#include <mruby/string.h>
#include <stdlib.h>

#include "../../../shared/embedded_ruflet_runtime.h"

@implementation RubyRuntimeMacosPlugin

static mrb_state *g_mrb = NULL;
static NSLock *g_lock = nil;
static BOOL g_server_running = NO;
static BOOL g_runtime_loaded = NO;
static NSString *g_stop_signal_path = nil;
static NSString *g_port_file_path = nil;
static NSString *g_last_server_error = nil;

static NSString *escape_single_quotes(NSString *text) {
  return [text stringByReplacingOccurrencesOfString:@"'" withString:@"\\\\'"];
}

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

static mrb_state *ensure_mrb(void) {
  if (g_mrb == NULL) {
    g_mrb = mrb_open();
  }
  return g_mrb;
}

static BOOL preload_embedded_runtime(mrb_state *mrb, NSError **error) {
  if (g_runtime_loaded) {
    return YES;
  }
  if (mrb == NULL) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"ruby_runtime"
                                   code:10
                               userInfo:@{NSLocalizedDescriptionKey: @"mruby runtime is not initialized"}];
    }
    return NO;
  }

  mrbc_context *context = mrbc_context_new(mrb);
  if (context == NULL) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"ruby_runtime"
                                   code:11
                               userInfo:@{NSLocalizedDescriptionKey: @"failed to create preload compile context"}];
    }
    return NO;
  }

  mrbc_filename(mrb, context, "/__ruflet__/embedded_runtime.rb");
  mrb_load_string_cxt(mrb, kEmbeddedRufletRuntime, context);
  mrbc_context_free(mrb, context);

  if (mrb->exc != NULL) {
    NSString *message = exception_to_string(mrb);
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"ruby_runtime"
                                   code:12
                               userInfo:@{NSLocalizedDescriptionKey: message}];
    }
    return NO;
  }

  g_runtime_loaded = YES;
  return YES;
}

static NSString *exception_to_string(mrb_state *mrb) {
  if (mrb == NULL || mrb->exc == NULL) {
    return @"unknown mruby error";
  }

  mrb_value exc = mrb_obj_value(mrb->exc);
  const char *klass = mrb_obj_classname(mrb, exc);
  NSString *backtraceText = nil;

  mrb_value backtrace = mrb_funcall(mrb, exc, "backtrace", 0);
  if (mrb->exc == NULL && !mrb_nil_p(backtrace)) {
    mrb_value renderedBacktrace = mrb_inspect(mrb, backtrace);
    if (mrb->exc == NULL) {
      const char *backtraceCString = mrb_string_value_cstr(mrb, &renderedBacktrace);
      if (backtraceCString != NULL) {
        backtraceText = [NSString stringWithUTF8String:backtraceCString];
      }
    }
  }
  if (mrb->exc != NULL) {
    mrb->exc = NULL;
  }

  mrb_value text = mrb_funcall(mrb, exc, "to_s", 0);
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

  NSString *k = klass == NULL ? @"Exception" : [NSString stringWithUTF8String:klass];
  NSString *m = msg == NULL ? @"<empty>" : ([NSString stringWithUTF8String:msg] ?: @"<invalid utf8>");
  if (backtraceText != nil && backtraceText.length > 0) {
    return [NSString stringWithFormat:@"%@: %@\n%@", k, m, backtraceText];
  }
  return [NSString stringWithFormat:@"%@: %@", k, m];
}

static NSString *eval_source(NSString *source, NSString *filename, NSError **error) {
  mrb_state *mrb = ensure_mrb();
  if (mrb == NULL) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"ruby_runtime"
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey: @"failed to initialize mruby runtime"}];
    }
    return nil;
  }
  if (!preload_embedded_runtime(mrb, error)) {
    return nil;
  }

  mrbc_context *context = mrbc_context_new(mrb);
  if (context == NULL) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"ruby_runtime"
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey: @"failed to create mruby compile context"}];
    }
    return nil;
  }

  if (filename != nil && filename.length > 0) {
    mrbc_filename(mrb, context, filename.UTF8String);
  }

  mrb_value result = mrb_load_string_cxt(mrb, source.UTF8String, context);
  mrbc_context_free(mrb, context);

  if (mrb->exc != NULL) {
    mrb_value exc = mrb_obj_value(mrb->exc);
    mrb->exc = NULL;
    mrb_exc_raise(mrb, exc);
  }
}

/* Returns the port the embedded server reported through RUFLET_PORT_FILE,
   or 0 when the server has not bound a port yet. */
static long read_server_port(void) {
  NSString *portPath = g_port_file_path;
  if (portPath == nil || portPath.length == 0) {
    return 0;
  }
  NSString *contents = [NSString stringWithContentsOfFile:portPath
                                                 encoding:NSUTF8StringEncoding
                                                    error:nil];
  if (contents == nil) {
    return 0;
  }
  long port = [contents stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]].integerValue;
  if (port <= 0 || port > 65535) {
    return 0;
  }
  return port;
}

static void request_stop_server(void) {
  if (g_stop_signal_path == nil || g_stop_signal_path.length == 0) {
    return;
  }
  [@"stop" writeToFile:g_stop_signal_path
            atomically:YES
              encoding:NSUTF8StringEncoding
                 error:nil];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"eval"]) {
    NSDictionary *args = (NSDictionary *)call.arguments;
    NSString *code = args[@"code"];
    if (![code isKindOfClass:[NSString class]] || code.length == 0) {
      result([FlutterError errorWithCode:@"invalid_args" message:@"Missing 'code' argument." details:nil]);
      return;
    }

    [g_lock lock];
    NSError *error = nil;
    NSString *value = eval_source(code, nil, &error);
    [g_lock unlock];

    if (error != nil) {
      result([FlutterError errorWithCode:@"mruby_error" message:error.localizedDescription details:nil]);
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
      } else if (g_mrb->exc != NULL) {
        runtime_error = [NSError errorWithDomain:@"ruby_runtime"
                                            code:1
                                        userInfo:@{NSLocalizedDescriptionKey : exception_to_string(g_mrb)}];
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

  if ([call.method isEqualToString:@"runFile"]) {
    NSDictionary *args = (NSDictionary *)call.arguments;
    NSString *path = args[@"path"];
    if (![path isKindOfClass:[NSString class]] || path.length == 0) {
      result([FlutterError errorWithCode:@"invalid_args" message:@"Missing 'path' argument." details:nil]);
      return;
    }

    NSError *readError = nil;
    NSString *source = [NSString stringWithContentsOfFile:path
                                                 encoding:NSUTF8StringEncoding
                                                    error:&readError];
    if (source == nil) {
      NSString *message = readError.localizedDescription ?: @"unable to read Ruby file";
      result([FlutterError errorWithCode:@"mruby_error" message:message details:nil]);
      return;
    }

    [g_lock lock];
    NSError *error = nil;
    NSString *value = eval_source(source, path, &error);
    [g_lock unlock];

    if (error != nil) {
      result([FlutterError errorWithCode:@"mruby_error" message:error.localizedDescription details:nil]);
      return;
    }
    result(value);
    return;
  }

  if ([call.method isEqualToString:@"reset"]) {
    if (g_server_running) {
      request_stop_server();
      result(nil);
      return;
    }

    [g_lock lock];
    if (g_mrb != NULL) {
      mrb_close(g_mrb);
      g_mrb = NULL;
    }
    g_runtime_loaded = NO;
    g_last_server_error = nil;
    g_port_file_path = nil;
    [g_lock unlock];
    result(nil);
    return;
  }

  if ([call.method isEqualToString:@"startFileServer"]) {
    NSDictionary *args = (NSDictionary *)call.arguments;
    NSString *path = args[@"path"];
    if (![path isKindOfClass:[NSString class]] || path.length == 0) {
      result([FlutterError errorWithCode:@"invalid_args" message:@"Missing 'path' argument." details:nil]);
      return;
    }
    if (g_server_running) {
      result(nil);
      return;
    }

    NSString *stopPath = args[@"stopSignalPath"];
    if (![stopPath isKindOfClass:[NSString class]] || stopPath.length == 0) {
      stopPath = [path stringByAppendingString:@".stop"];
    }

    [[NSFileManager defaultManager] removeItemAtPath:stopPath error:nil];
    g_stop_signal_path = stopPath;

    NSString *portFilePath =
        [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"server.port"];
    [[NSFileManager defaultManager] removeItemAtPath:portFilePath error:nil];
    g_port_file_path = portFilePath;

    NSError *readError = nil;
    NSString *source = [NSString stringWithContentsOfFile:path
                                                 encoding:NSUTF8StringEncoding
                                                    error:&readError];
    if (source == nil) {
      NSString *message = readError.localizedDescription ?: @"unable to read Ruby file";
      g_last_server_error = message;
      result([FlutterError errorWithCode:@"mruby_error" message:message details:nil]);
      return;
    }
    NSString *safeAppRoot = escape_single_quotes([path stringByDeletingLastPathComponent]);
    /* The embedded VM's ENV is isolated from the process environment, so
       configuration must be seeded through the Ruby prelude. The server binds
       any free port and reports the bound port through RUFLET_PORT_FILE. */
    source = [NSString stringWithFormat:
      @"$__ruflet_app_root = '%@'\n"
      @"ENV['RUFLET_PROD_STOP_FILE'] = '%@' if Object.const_defined?(:ENV)\n"
      @"ENV['RUFLET_PORT_FILE'] = '%@' if Object.const_defined?(:ENV)\n"
      @"%@",
      safeAppRoot, escape_single_quotes(stopPath), escape_single_quotes(portFilePath), source];

    g_last_server_error = nil;
    g_server_running = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      setenv("RUFLET_PROD_STOP_FILE", stopPath.UTF8String, 1);
      setenv("RUFLET_PORT_FILE", portFilePath.UTF8String, 1);
      [g_lock lock];
      NSError *error = nil;
      NSString *value = eval_source(source, path, &error);
      if (error == nil && value != nil && [value hasPrefix:@":"]) {
        NSString *safePath = escape_single_quotes(path);
        NSString *bootstrap = [NSString stringWithFormat:
          @"app_root = File.expand_path(File.dirname('%@')); "
          "manifest_path = File.join(app_root, 'manifest.json'); "
          "manifest = RufletProd::JsonParser.parse(File.read(manifest_path)); "
          "RufletProd::Server.new(host: '0.0.0.0', port: 8550, manifest: manifest).start",
          safePath];
        value = eval_source(bootstrap, path, &error);
      }
      if (error != nil) {
        g_last_server_error = error.localizedDescription;
        NSLog(@"[ruby_runtime] startFileServer crash: %@", g_last_server_error);
      } else {
        NSString *resultValue = value ?: @"";
        g_last_server_error = [NSString stringWithFormat:@"server script exited: %@", resultValue];
        NSLog(@"[ruby_runtime] %@", g_last_server_error);
      }
      [g_lock unlock];
      g_server_running = NO;
    });

    result(nil);
    return;
  }

  if ([call.method isEqualToString:@"stopFileServer"]) {
    request_stop_server();
    result(nil);
    return;
  }

  if ([call.method isEqualToString:@"isFileServerRunning"]) {
    result(@(g_server_running));
    return;
  }

  if ([call.method isEqualToString:@"serverPort"]) {
    result(@(read_server_port()));
    return;
  }

  if ([call.method isEqualToString:@"lastFileServerError"]) {
    result(g_last_server_error ?: @"");
    return;
  }

  result(FlutterMethodNotImplemented);
}

@end
