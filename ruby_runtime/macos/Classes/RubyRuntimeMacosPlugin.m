#import "RubyRuntimeMacosPlugin.h"

#include <mruby.h>
#include <mruby/compile.h>
#include <mruby/string.h>
#include <stdlib.h>

@implementation RubyRuntimeMacosPlugin

static mrb_state *g_mrb = NULL;
static NSLock *g_lock = nil;
static BOOL g_server_running = NO;
static NSString *g_stop_signal_path = nil;
static NSString *g_last_server_error = nil;

static NSString *escape_single_quotes(NSString *text) {
  return [text stringByReplacingOccurrencesOfString:@"'" withString:@"\\\\'"];
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"ruby_runtime"
                                                              binaryMessenger:[registrar messenger]];
  RubyRuntimeMacosPlugin *instance = [[RubyRuntimeMacosPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    if (g_lock == nil) {
      g_lock = [[NSLock alloc] init];
    }
  }
  return self;
}

static mrb_state *ensure_mrb(void) {
  if (g_mrb == NULL) {
    g_mrb = mrb_open();
  }
  return g_mrb;
}

static NSString *exception_to_string(mrb_state *mrb) {
  if (mrb == NULL || mrb->exc == NULL) {
    return @"unknown mruby error";
  }

  mrb_value exc = mrb_obj_value(mrb->exc);
  const char *klass = mrb_obj_classname(mrb, exc);

  mrb_value text = mrb_funcall(mrb, exc, "to_s", 0);
  if (mrb->exc != NULL) {
    mrb->exc = NULL;
    NSString *k = klass == NULL ? @"Exception" : [NSString stringWithUTF8String:klass];
    return [NSString stringWithFormat:@"%@: <failed to render exception message>", k];
  }

  const char *msg = mrb_string_value_cstr(mrb, &text);
  mrb->exc = NULL;

  NSString *k = klass == NULL ? @"Exception" : [NSString stringWithUTF8String:klass];
  NSString *m = msg == NULL ? @"<empty>" : ([NSString stringWithUTF8String:msg] ?: @"<invalid utf8>");
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
    NSString *message = exception_to_string(mrb);
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"ruby_runtime"
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey: message}];
    }
    return nil;
  }

  mrb_value display = result;
  if (!mrb_string_p(result)) {
    display = mrb_inspect(mrb, result);
    if (mrb->exc != NULL) {
      NSString *message = exception_to_string(mrb);
      if (error != NULL) {
        *error = [NSError errorWithDomain:@"ruby_runtime"
                                     code:4
                                 userInfo:@{NSLocalizedDescriptionKey: message}];
      }
      return nil;
    }
  }

  const char *value = mrb_string_value_cstr(mrb, &display);
  if (value == NULL) {
    return @"";
  }
  return [NSString stringWithUTF8String:value] ?: @"";
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
    result(value);
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
    g_last_server_error = nil;
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

    g_last_server_error = nil;
    g_server_running = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      setenv("RUFLET_PROD_STOP_FILE", stopPath.UTF8String, 1);
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

  if ([call.method isEqualToString:@"lastFileServerError"]) {
    result(g_last_server_error ?: @"");
    return;
  }

  result(FlutterMethodNotImplemented);
}

@end
