#pragma once

// Platform-side startup for the embedded Ruby VM, shared by the iOS and macOS
// bridges.
//
// The VM is started from the plugin class's +load, which runs when the dylib is
// loaded -- before UIApplicationMain, before the Flutter engine exists and long
// before Dart could ask for it. It boots on a background queue in parallel with
// the engine and exposes an in-process endpoint as soon as the VM owns its
// protocol queues.
//
// The packaged Ruby project is read straight out of the app bundle. Flutter
// assets are ordinary files there, so nothing has to be copied to a writable
// directory first -- which also removes the per-file extraction the Dart side
// used to do before it could even call start().
//
// The packaged project is the opt-in: a self-contained build ships one and a
// server-driven build does not, which is exactly the distinction that matters.
// Nothing has to be configured for an application to get this, so it does not
// depend on which version of the CLI generated the client. Setting
// RufletRuntimeAutostart to false in Info.plist turns it off for an app that
// wants to drive startup from Dart anyway.
//
// Header-only, with internal linkage, because each platform compiles exactly
// one bridge translation unit. It mirrors how both bridges already share
// desktop/ruflet_vm_host.h.

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#include <mach/mach_time.h>
#include <stdlib.h>
#include <unistd.h>

#include "ruflet_vm_host.h"

#pragma mark - Timeline

static uint64_t ruflet_load_ticks = 0;
static mach_timebase_info_data_t ruflet_timebase = {0, 0};

/// Milliseconds since the plugin's dylib was loaded. Lets Dart place its own
/// timestamps on a timeline that starts before the engine did, which is the
/// only way to see how much of startup happens before the VM is asked to boot.
static double ruflet_ms_since_load(void) {
  if (ruflet_load_ticks == 0 || ruflet_timebase.denom == 0) {
    return -1.0;
  }
  const uint64_t elapsed = mach_absolute_time() - ruflet_load_ticks;
  return (double)elapsed * (double)ruflet_timebase.numer /
         (double)ruflet_timebase.denom / 1000000.0;
}

#pragma mark - Autostart state

static NSString *ruflet_server_url = nil;
static NSString *ruflet_autostart_error = nil;
static NSCondition *ruflet_autostart_signal = nil;
static BOOL ruflet_autostart_attempted = NO;

static NSString *ruflet_entrypoint_at_root(NSString *root) {
  NSFileManager *files = [NSFileManager defaultManager];
  for (NSString *name in @[@"main.mrb", @"main.rb"]) {
    NSString *candidate = [root stringByAppendingPathComponent:name];
    if ([files fileExistsAtPath:candidate]) {
      return candidate;
    }
  }
  return nil;
}

/// Where `flutter build` puts the asset bundle. iOS keeps flutter_assets at the
/// root of App.framework; macOS nests it under Resources.
static NSString *ruflet_flutter_assets_dir(void) {
  NSString *frameworks = [[NSBundle mainBundle] privateFrameworksPath];
  if (frameworks == nil) {
    return nil;
  }
  NSFileManager *files = [NSFileManager defaultManager];
  NSArray<NSString *> *candidates = @[
    [frameworks stringByAppendingPathComponent:@"App.framework/flutter_assets"],
    [frameworks
        stringByAppendingPathComponent:@"App.framework/Resources/flutter_assets"]
  ];
  for (NSString *candidate in candidates) {
    BOOL directory = NO;
    if ([files fileExistsAtPath:candidate isDirectory:&directory] && directory) {
      return candidate;
    }
  }
  return nil;
}

/// The packaged project is the single directory under flutter_assets/assets
/// holding a main.rb. RufletEmbeddedProject in Info.plist names it explicitly
/// when an app packages more than one.
static NSString *ruflet_packaged_project_root(void) {
  NSString *assets = ruflet_flutter_assets_dir();
  if (assets == nil) {
    return nil;
  }
  NSString *root = [assets stringByAppendingPathComponent:@"assets"];
  NSFileManager *files = [NSFileManager defaultManager];

  NSString *configured =
      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"RufletEmbeddedProject"];
  if ([configured isKindOfClass:[NSString class]] && configured.length > 0) {
    NSString *candidate = [root stringByAppendingPathComponent:configured];
    return ruflet_entrypoint_at_root(candidate) != nil ? candidate : nil;
  }

  NSArray<NSString *> *entries = [files contentsOfDirectoryAtPath:root error:nil];
  NSString *found = nil;
  for (NSString *entry in entries) {
    NSString *candidate = [root stringByAppendingPathComponent:entry];
    if (ruflet_entrypoint_at_root(candidate) == nil) {
      continue;
    }
    if (found != nil) {
      return nil; // Ambiguous; the app must name one in Info.plist.
    }
    found = candidate;
  }
  return found;
}

static BOOL ruflet_full_runtime_profile(NSString *root) {
  NSString *path = [root stringByAppendingPathComponent:@".ruflet-runtime.json"];
  NSData *data = [NSData dataWithContentsOfFile:path];
  if (data == nil) {
    return NO;
  }
  NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:data
                                                            options:0
                                                              error:nil];
  return [manifest[@"profile"] isEqualToString:@"full"];
}

static BOOL ruflet_supports_in_process_transport(NSString *root) {
  NSString *ruby = [root stringByAppendingPathComponent:@"vendor/bundle/ruby"];
  NSDirectoryEnumerator<NSString *> *entries =
      [[NSFileManager defaultManager] enumeratorAtPath:ruby];
  for (NSString *entry in entries) {
    if ([entry hasSuffix:@"/lib/ruflet/server/in_process_connection.rb"] &&
        [entry containsString:@"/gems/ruflet_server-"]) {
      return YES;
    }
  }
  return NO;
}

static void ruflet_finish_autostart(NSString *url, NSString *error) {
  [ruflet_autostart_signal lock];
  ruflet_server_url = url;
  ruflet_autostart_error = error;
  [ruflet_autostart_signal broadcast];
  [ruflet_autostart_signal unlock];
}

static void ruflet_begin_autostart(void) {
  NSString *root = ruflet_packaged_project_root();
  if (root == nil) {
    ruflet_finish_autostart(
        nil, @"No packaged Ruby project was found in the app bundle. Build with "
             @"`ruflet build --self`, or name the project with "
             @"RufletEmbeddedProject in Info.plist.");
    return;
  }
  if (ruflet_full_runtime_profile(root) &&
      !ruflet_supports_in_process_transport(root)) {
    ruflet_finish_autostart(
        nil, @"The locked ruflet_server gem does not support port-free self "
             @"builds. Update the application's Gemfile.lock.");
    return;
  }

  // The bundle is read-only, so the runtime's scratch files live in the app's
  // temporary directory rather than beside the sources.
  NSString *scratch =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"ruflet-runtime"];
  [[NSFileManager defaultManager] createDirectoryAtPath:scratch
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:nil];
  NSString *errorPath = [scratch stringByAppendingPathComponent:@"server.error"];
  NSString *stopPath = [scratch stringByAppendingPathComponent:@"server.stop"];
  [[NSFileManager defaultManager] removeItemAtPath:errorPath error:nil];
  [[NSFileManager defaultManager] removeItemAtPath:stopPath error:nil];

  NSString *entrypoint = ruflet_entrypoint_at_root(root);
  NSString *assetsDir = [root stringByAppendingPathComponent:@"assets"];

  // The full CRuby distribution carries its standard library as a CocoaPods
  // resource. Keep the lite package's one-path fast path unchanged, while
  // giving the ABI-compatible CRuby host both its Ruby and native-extension
  // directories before it loads the application bundle.
#if defined(RUFLET_CRUBY_RUNTIME)
  NSString *pluginClassName = @"RubyRuntimeMacosPlugin";
#if TARGET_OS_IOS
  pluginClassName = @"MrubyRuntimePlugin";
#endif
  NSBundle *crubyBundle =
      [NSBundle bundleForClass:NSClassFromString(pluginClassName)];
  NSString *crubyRoot = [[crubyBundle resourcePath]
      stringByAppendingPathComponent:@"ruflet_cruby"];
  NSString *crubyLib = [[crubyRoot stringByAppendingPathComponent:@"lib/ruby"]
      stringByAppendingPathComponent:RUFLET_CRUBY_ABI];
  NSString *crubyArch =
      [crubyLib stringByAppendingPathComponent:RUFLET_CRUBY_ARCH];
  const char *loadPaths[] = {root.UTF8String, crubyLib.UTF8String,
                             crubyArch.UTF8String};
  const size_t loadPathCount = 3;
#else
  const char *loadPaths[] = {root.UTF8String};
  const size_t loadPathCount = 1;
#endif
  const char *environmentKeys[] = {
      "RUFLET_ASSETS_DIR", "RUFLET_RUNTIME_ERROR_FILE",
      "RUFLET_SUPPRESS_SERVER_BANNER", "RUFLET_RUNTIME_TRANSPORT"};
  const char *environmentValues[] = {assetsDir.UTF8String, errorPath.UTF8String,
                                     "1", "in_process"};

  const int status = ruflet_vm_start(
      root.UTF8String, entrypoint.UTF8String, loadPaths, loadPathCount, environmentKeys,
      environmentValues, 4, stopPath.UTF8String, errorPath.UTF8String);
  if (status != 0) {
    ruflet_finish_autostart(
        nil, @"The packaged entrypoint was rejected by the VM; it must be a "
             @".rb or .mrb file inside the project root.");
    return;
  }
  ruflet_finish_autostart(@"inprocess://embedded", nil);
}

/// Call from the plugin class's +load. Records the timeline origin and, unless
/// the app opted out, kicks the VM off on a background queue.
static void ruflet_autostart_on_load(void) {
  mach_timebase_info(&ruflet_timebase);
  ruflet_load_ticks = mach_absolute_time();
  ruflet_autostart_signal = [[NSCondition alloc] init];

  NSNumber *enabled = [[NSBundle mainBundle]
      objectForInfoDictionaryKey:@"RufletRuntimeAutostart"];
  if ([enabled isKindOfClass:[NSNumber class]] && !enabled.boolValue) {
    return;
  }
  // No packaged project means a server-driven app, which must not boot a VM.
  if (ruflet_packaged_project_root() == nil) {
    return;
  }

  ruflet_autostart_attempted = YES;
  // Off the main thread: +load runs during dylib loading and anything slow here
  // delays the whole app, which would trade the win away.
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    ruflet_begin_autostart();
  });
}

/// Answers the `serverUrl` method call. Waits on a background queue -- never on
/// the platform thread -- and replies as soon as the URL (or a failure) exists.
static void ruflet_autostart_resolve_url(FlutterResult result) {
  if (!ruflet_autostart_attempted) {
    result([FlutterError
        errorWithCode:@"autostart_disabled"
              message:@"This app does not start the runtime from the platform "
                      @"layer. Set RufletRuntimeAutostart in Info.plist to use "
                      @"serverUrl(), or call start() instead."
              details:nil]);
    return;
  }

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    [ruflet_autostart_signal lock];
    while (ruflet_server_url == nil && ruflet_autostart_error == nil) {
      [ruflet_autostart_signal wait];
    }
    NSString *url = ruflet_server_url;
    NSString *failure = ruflet_autostart_error;
    [ruflet_autostart_signal unlock];

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
}

/// Sends one complete binary protocol message from the renderer to Ruby.
static void ruflet_bridge_send_from_renderer(id arguments,
                                             FlutterResult result) {
  if (![arguments isKindOfClass:[FlutterStandardTypedData class]]) {
    result([FlutterError errorWithCode:@"ruflet_bridge_bad_message"
                               message:@"bridgeSend requires binary data."
                               details:nil]);
    return;
  }
  NSData *data = ((FlutterStandardTypedData *)arguments).data;
  const int status = ruflet_bridge_send_to_ruby(
      (const uint8_t *)data.bytes, (size_t)data.length);
  if (status != RUFLET_BRIDGE_MESSAGE) {
    result([FlutterError errorWithCode:@"ruflet_bridge_closed"
                               message:@"The Ruflet in-process bridge is closed."
                               details:nil]);
    return;
  }
  result(nil);
}

/// Waits off the platform thread for one complete message from Ruby.
static void ruflet_bridge_receive_for_flutter(FlutterResult result) {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    uint8_t *bytes = NULL;
    size_t length = 0;
    const int status = ruflet_bridge_receive_for_renderer(&bytes, &length);
    NSData *message = status == RUFLET_BRIDGE_MESSAGE
                          ? [NSData dataWithBytes:bytes length:length]
                          : nil;
    ruflet_bridge_free_message(bytes);

    dispatch_async(dispatch_get_main_queue(), ^{
      if (status == RUFLET_BRIDGE_MESSAGE) {
        result([FlutterStandardTypedData typedDataWithBytes:message]);
      } else if (status == RUFLET_BRIDGE_CLOSED) {
        result(nil);
      } else {
        result([FlutterError
            errorWithCode:@"ruflet_bridge_receive_failed"
                  message:@"Unable to receive from the Ruflet in-process bridge."
                  details:nil]);
      }
    });
  });
}

/// True when the platform owns the runtime, so a start() call cannot take
/// effect. The VM boots once per process: ruflet_vm_start would see a running
/// VM and return success without adopting any of the arguments.
static BOOL ruflet_autostart_owns_runtime(void) {
  return ruflet_autostart_attempted;
}
