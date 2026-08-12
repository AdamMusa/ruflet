import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ruflet_runtime.dart';
import 'ruflet_runtime_method_channel.dart';

abstract class RufletRuntimePlatform extends PlatformInterface {
  RufletRuntimePlatform() : super(token: _token);

  static final Object _token = Object();

  static RufletRuntimePlatform _instance = MethodChannelRufletRuntime();

  static RufletRuntimePlatform get instance => _instance;

  static set instance(RufletRuntimePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<RufletRuntimeStatus> start({
    required String projectRoot,
    required String entrypoint,
    List<String> loadPaths = const [],
    Map<String, String> environment = const {},
    String? errorFilePath,
    String? stopSignalPath,
  }) {
    throw UnimplementedError('start() has not been implemented.');
  }

  Future<Uri> serverUrl() {
    throw UnimplementedError('serverUrl() has not been implemented.');
  }

  Future<RufletRuntimeStatus> status() {
    throw UnimplementedError('status() has not been implemented.');
  }

  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }
}
