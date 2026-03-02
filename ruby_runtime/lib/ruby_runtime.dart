import 'ruby_runtime_platform_interface.dart';

class RubyRuntime {
  RubyRuntime._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await RubyRuntimePlatform.instance.reset();
    _initialized = true;
  }

  static Future<String> eval(String code) {
    return RubyRuntimePlatform.instance.eval(code);
  }

  static Future<String> runFile(String path) {
    return RubyRuntimePlatform.instance.runFile(path);
  }

  static Future<void> reset() {
    return RubyRuntimePlatform.instance.reset();
  }

  static Future<void> startFileServer(String path, {String? stopSignalPath}) {
    return RubyRuntimePlatform.instance.startFileServer(
      path,
      stopSignalPath: stopSignalPath,
    );
  }

  static Future<void> stopFileServer() {
    return RubyRuntimePlatform.instance.stopFileServer();
  }

  static Future<bool> isFileServerRunning() {
    return RubyRuntimePlatform.instance.isFileServerRunning();
  }
}
