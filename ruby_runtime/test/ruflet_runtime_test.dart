import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ruby_runtime/ruflet_runtime.dart';
import 'package:ruby_runtime/ruflet_runtime_method_channel.dart';
import 'package:ruby_runtime/ruflet_runtime_platform_interface.dart';

class MockRufletRuntimePlatform
    with MockPlatformInterfaceMixin
    implements RufletRuntimePlatform {
  @override
  Future<RufletRuntimeStatus> start({
    required String projectRoot,
    required String entrypoint,
    List<String> loadPaths = const [],
    Map<String, String> environment = const {},
    String? errorFilePath,
    String? stopSignalPath,
  }) async {
    return const RufletRuntimeStatus(running: true, port: 8550, error: '');
  }

  @override
  Future<Uri> serverUrl() async => Uri.parse('http://127.0.0.1:8550');

  @override
  Future<RufletRuntimeStatus> status() async {
    return const RufletRuntimeStatus(running: true, port: 8550, error: '');
  }

  @override
  Future<void> stop() async {}
}

void main() {
  final initialPlatform = RufletRuntimePlatform.instance;

  test('$MethodChannelRufletRuntime is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRufletRuntime>());
  });

  test('runtime API exposes only Ruflet server lifecycle', () async {
    RufletRuntimePlatform.instance = MockRufletRuntimePlatform();

    final started = await RufletRuntime.start(
      projectRoot: '/tmp/demo',
      entrypoint: '/tmp/demo/main.mrb',
    );
    expect(started.running, true);
    expect(started.port, 8550);
    expect((await RufletRuntime.status()).error, '');
    expect((await RufletRuntime.serverUrl()).port, 8550);
    await RufletRuntime.stop();
  });
}
