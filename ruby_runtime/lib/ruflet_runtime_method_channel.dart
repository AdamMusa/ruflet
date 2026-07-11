import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ruflet_runtime.dart';
import 'ruflet_runtime_platform_interface.dart';

class MethodChannelRufletRuntime extends RufletRuntimePlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('ruflet_runtime');

  @override
  Future<RufletRuntimeStatus> start({
    required String projectRoot,
    required String entrypoint,
    String? stopSignalPath,
  }) async {
    final value = await methodChannel
        .invokeMapMethod<Object?, Object?>('start', {
          'projectRoot': projectRoot,
          'entrypoint': entrypoint,
          if (stopSignalPath != null && stopSignalPath.isNotEmpty)
            'stopSignalPath': stopSignalPath,
        });
    return _statusFromNative(value, 'start');
  }

  @override
  Future<RufletRuntimeStatus> status() async {
    final value = await methodChannel.invokeMapMethod<Object?, Object?>(
      'status',
    );
    return _statusFromNative(value, 'status');
  }

  @override
  Future<void> stop() async {
    await methodChannel.invokeMethod<void>('stop');
  }

  RufletRuntimeStatus _statusFromNative(
    Map<Object?, Object?>? value,
    String method,
  ) {
    if (value == null) {
      throw PlatformException(
        code: 'ruflet_runtime_null_status',
        message: 'Native Ruflet runtime returned no status from $method().',
      );
    }
    return RufletRuntimeStatus.fromMap(value);
  }
}
