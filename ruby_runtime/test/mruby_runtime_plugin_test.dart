import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ruby_runtime/ruby_runtime.dart';
import 'package:ruby_runtime/ruby_runtime_method_channel.dart';
import 'package:ruby_runtime/ruby_runtime_platform_interface.dart';

class MockRubyRuntimePlatform
    with MockPlatformInterfaceMixin
    implements RubyRuntimePlatform {
  @override
  Future<String> eval(String code) async => 'eval:$code';

  @override
  Future<String> runFile(String path) async => 'file:$path';

  @override
  Future<void> reset() async {}

  @override
  Future<void> startFileServer(String path, {String? stopSignalPath}) async {}

  @override
  Future<void> stopFileServer() async {}

  @override
  Future<bool> isFileServerRunning() async => true;

  @override
  Future<String> lastFileServerError() async => '';
}

void main() {
  final RubyRuntimePlatform initialPlatform = RubyRuntimePlatform.instance;

  test('$MethodChannelRubyRuntime is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRubyRuntime>());
  });

  test('plugin API delegates to platform', () async {
    RubyRuntimePlatform.instance = MockRubyRuntimePlatform();

    expect(await RubyRuntime.eval('1+1'), 'eval:1+1');
    expect(await RubyRuntime.runFile('/tmp/demo.rb'), 'file:/tmp/demo.rb');
    await RubyRuntime.startFileServer('/tmp/demo.rb');
    expect(await RubyRuntime.isFileServerRunning(), true);
    expect(await RubyRuntime.lastFileServerError(), '');
    await RubyRuntime.stopFileServer();
    await RubyRuntime.reset();
  });
}
