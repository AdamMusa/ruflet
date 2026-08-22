import 'dart:typed_data';

import 'ruflet_runtime_platform_interface.dart';

class RufletRuntimeStatus {
  const RufletRuntimeStatus({
    required this.running,
    required this.port,
    required this.error,
  });

  factory RufletRuntimeStatus.fromMap(Map<Object?, Object?> value) {
    return RufletRuntimeStatus(
      running: value['running'] == true,
      port: value['port'] is int ? value['port']! as int : 0,
      error: value['error']?.toString() ?? '',
    );
  }

  final bool running;
  final int port;
  final String error;
}

class RufletRuntime {
  RufletRuntime._();

  static Future<RufletRuntimeStatus> start({
    required String projectRoot,
    required String entrypoint,
    List<String> loadPaths = const [],
    Map<String, String> environment = const {},
    String? errorFilePath,
    String? stopSignalPath,
  }) {
    return RufletRuntimePlatform.instance.start(
      projectRoot: projectRoot,
      entrypoint: entrypoint,
      loadPaths: loadPaths,
      environment: environment,
      errorFilePath: errorFilePath,
      stopSignalPath: stopSignalPath,
    );
  }

  /// The endpoint of a runtime the platform layer started on its own.
  /// Packaged Apple applications return `inprocess://embedded`.
  static Future<Uri> serverUrl() {
    return RufletRuntimePlatform.instance.serverUrl();
  }

  static Future<RufletRuntimeStatus> status() {
    return RufletRuntimePlatform.instance.status();
  }

  static Future<void> sendToRuby(Uint8List message) {
    return RufletRuntimePlatform.instance.sendToRuby(message);
  }

  static Future<Uint8List?> receiveFromRuby() {
    return RufletRuntimePlatform.instance.receiveFromRuby();
  }

  static Future<void> closeBridge() {
    return RufletRuntimePlatform.instance.closeBridge();
  }

  static Future<void> stop() {
    return RufletRuntimePlatform.instance.stop();
  }
}
