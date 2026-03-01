import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ruby_runtime_method_channel.dart';

abstract class RubyRuntimePlatform extends PlatformInterface {
  RubyRuntimePlatform() : super(token: _token);

  static final Object _token = Object();

  static RubyRuntimePlatform _instance = MethodChannelRubyRuntime();

  static RubyRuntimePlatform get instance => _instance;

  static set instance(RubyRuntimePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String> eval(String code) {
    throw UnimplementedError('eval() has not been implemented.');
  }

  Future<String> runFile(String path) {
    throw UnimplementedError('runFile() has not been implemented.');
  }

  Future<void> reset() {
    throw UnimplementedError('reset() has not been implemented.');
  }
}
