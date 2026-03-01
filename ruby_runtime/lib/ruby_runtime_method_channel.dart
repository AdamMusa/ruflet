import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ruby_runtime_platform_interface.dart';

class MethodChannelRubyRuntime extends RubyRuntimePlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('ruby_runtime');

  @override
  Future<String> eval(String code) async {
    final result = await methodChannel.invokeMethod<String>('eval', {
      'code': code,
    });
    if (result == null) {
      throw PlatformException(
        code: 'ruby_runtime_null_result',
        message: 'Native runtime returned null for eval().',
      );
    }
    return result;
  }

  @override
  Future<String> runFile(String path) async {
    final result = await methodChannel.invokeMethod<String>('runFile', {
      'path': path,
    });
    if (result == null) {
      throw PlatformException(
        code: 'ruby_runtime_null_result',
        message: 'Native runtime returned null for runFile().',
      );
    }
    return result;
  }

  @override
  Future<void> reset() async {
    await methodChannel.invokeMethod<void>('reset');
  }
}
