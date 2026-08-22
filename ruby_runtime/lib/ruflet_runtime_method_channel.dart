import 'dart:typed_data';

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
    List<String> loadPaths = const [],
    Map<String, String> environment = const {},
    String? errorFilePath,
    String? stopSignalPath,
  }) async {
    final value = await methodChannel
        .invokeMapMethod<Object?, Object?>('start', {
          'projectRoot': projectRoot,
          'entrypoint': entrypoint,
          'loadPaths': loadPaths,
          'environment': environment,
          if (errorFilePath != null && errorFilePath.isNotEmpty)
            'errorFilePath': errorFilePath,
          if (stopSignalPath != null && stopSignalPath.isNotEmpty)
            'stopSignalPath': stopSignalPath,
        });
    return _statusFromNative(value, 'start');
  }

  @override
  Future<Uri> serverUrl() async {
    final value = await methodChannel.invokeMapMethod<Object?, Object?>(
      'serverUrl',
    );
    final raw = value?['url']?.toString() ?? '';
    final parsed = Uri.tryParse(raw);
    if (parsed == null || parsed.host.isEmpty) {
      throw PlatformException(
        code: 'ruflet_runtime_bad_url',
        message: 'Native Ruflet runtime returned an unusable URL: "$raw".',
      );
    }
    return parsed;
  }

  @override
  Future<RufletRuntimeStatus> status() async {
    final value = await methodChannel.invokeMapMethod<Object?, Object?>(
      'status',
    );
    return _statusFromNative(value, 'status');
  }

  @override
  Future<void> sendToRuby(Uint8List message) async {
    await methodChannel.invokeMethod<void>('bridgeSend', message);
  }

  @override
  Future<Uint8List?> receiveFromRuby() {
    return methodChannel.invokeMethod<Uint8List>('bridgeReceive');
  }

  @override
  Future<void> closeBridge() async {
    await methodChannel.invokeMethod<void>('bridgeClose');
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
