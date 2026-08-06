#pragma once

// Platform-side startup for the embedded Ruby VM, shared by the iOS and macOS
// bridges.
//
// The VM is started from the plugin class's +load, which runs when the dylib is
// loaded -- before UIApplicationMain, before the Flutter engine exists and long
// before Dart could ask for it. It boots on a background queue in parallel with
// the engine, so by the time Dart calls serverUrl() the embedded server has
// usually already bound its port.
//
// The packaged Ruby project is read straight out of the app bundle. Flutter
// assets are ordinary files there, so nothing has to be copied to a writable
// directory first -- which also removes the per-file extraction the Dart side
// used to do before it could even call start().
//
// Autostart is opt-in through RufletRuntimeAutostart in Info.plist: a
// server-driven app has no packaged project and must not boot a VM, and an app
// that still wants to configure the runtime from Dart keeps start().
//
// Header-only, with internal linkage, because each platform compiles exactly
// one bridge translation unit. It mirrors how both bridges already share
// desktop/ruflet_vm_host.h.

#import <Foundation/Foundation.h>

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
    return [files
               fileExistsAtPath:[candidate
                                    stringByAppendingPathComponent:@"main.rb"]]
               ? candidate
               : nil;
  }

  NSArray<NSString *> *entries = [files contentsOfDirectoryAtPath:root error:nil];
  NSString *found = nil;
  for (NSString *entry in entries) {
    NSString *candidate = [root stringByAppendingPathComponent:entry];
    if (![files
            fileExistsAtPath:[candidate
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

  // The bundle is read-only, so the runtime's scratch files live in the app's
  // temporary directory rather than beside the sources.
  NSString *scratch =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"ruflet-runtime"];
  [[NSFileManager defaultManager] createDirectoryAtPath:scratch
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:nil];
  NSString *portPath = [scratch stringByAppendingPathComponent:@"server.port"];
  NSString *errorPath = [scratch stringByAppendingPathComponent:@"server.error"];
  NSString *stopPath = [scratch stringByAppendingPathComponent:@"server.stop"];
  [[NSFileManager defaultManager] removeItemAtPath:portPath error:nil];
  [[NSFileManager defaultManager] removeItemAtPath:errorPath error:nil];
  [[NSFileManager defaultManager] removeItemAtPath:stopPath error:nil];

  NSString *entrypoint = [root stringByAppendingPathComponent:@"main.rb"];
  NSString *assetsDir = [root stringByAppendingPathComponent:@"assets"];

  const char *loadPaths[] = {root.UTF8String};
  const char *environmentKeys[] = {
      "RUFLET_PORT", "RUFLET_ASSETS_DIR", "RUFLET_RUNTIME_PORT_FILE",
      "RUFLET_RUNTIME_ERROR_FILE", "RUFLET_SUPPRESS_SERVER_BANNER"};
  const char *environmentValues[] = {"0", assetsDir.UTF8String,
                                     portPath.UTF8String, errorPath.UTF8String,
                                     "1"};

  const int status = ruflet_vm_start(
      root.UTF8String, entrypoint.UTF8String, loadPaths, 1, environmentKeys,
      environmentValues, 5, stopPath.UTF8String, errorPath.UTF8String);
  if (status != 0) {
    ruflet_finish_autostart(
        nil, @"The packaged entrypoint was rejected by the VM; it must be a "
             @".rb or .mrb file inside the project root.");
    return;
  }

  // Poll for the port the Ruby server publishes. Tight, because this runs off
  // the main thread and the whole point is to have an answer ready early.
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:30.0];
  while ([deadline timeIntervalSinceNow] > 0) {
    NSString *published = [NSString stringWithContentsOfFile:portPath
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    const int port = published == nil ? 0 : published.intValue;
    if (port > 0) {
      ruflet_finish_autostart(
          [NSString stringWithFormat:@"http://127.0.0.1:%d", port], nil);
      return;
    }
    NSString *failure = [NSString stringWithContentsOfFile:errorPath
                                                 encoding:NSUTF8StringEncoding
                                                    error:nil];
    if (failure.length > 0) {
      ruflet_finish_autostart(nil, failure);
      return;
    }
    usleep(1000);
  }
  ruflet_finish_autostart(nil,
                          @"The embedded Ruflet server did not publish a port.");
}

/// Call from the plugin class's +load. Records the timeline origin and, when
/// the app opted in, kicks the VM off on a background queue.
static void ruflet_autostart_on_load(void) {
  mach_timebase_info(&ruflet_timebase);
  ruflet_load_ticks = mach_absolute_time();
  ruflet_autostart_signal = [[NSCondition alloc] init];

  NSNumber *enabled = [[NSBundle mainBundle]
      objectForInfoDictionaryKey:@"RufletRuntimeAutostart"];
  if (![enabled isKindOfClass:[NSNumber class]] || !enabled.boolValue) {
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

/// True when the platform owns the runtime, so a start() call cannot take
/// effect. The VM boots once per process: ruflet_vm_start would see a running
/// VM and return success without adopting any of the arguments, leaving the
/// caller waiting on a port file nothing will write.
static BOOL ruflet_autostart_owns_runtime(void) {
  return ruflet_autostart_attempted;
}
