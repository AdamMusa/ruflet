import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ruby_runtime/ruflet_runtime.dart';
import 'package:ruby_runtime/ruflet_runtime_method_channel.dart';
import 'package:ruby_runtime/ruflet_runtime_platform_interface.dart';

class MockRufletRuntimePlatform
    with MockPlatformInterfaceMixin
    implements RufletRuntimePlatform {
  Uint8List? sentMessage;

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
  Future<Uri> serverUrl() async => Uri.parse('inprocess://embedded');

  @override
  Future<RufletRuntimeStatus> status() async {
    return const RufletRuntimeStatus(running: true, port: 8550, error: '');
  }

  @override
  Future<void> sendToRuby(Uint8List message) async {
    sentMessage = message;
  }

  @override
  Future<Uint8List?> receiveFromRuby() async => Uint8List.fromList([4, 5, 6]);

  @override
  Future<void> closeBridge() async {}

  @override
  Future<void> stop() async {}
}

void main() {
  final initialPlatform = RufletRuntimePlatform.instance;

  test('$MethodChannelRufletRuntime is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRufletRuntime>());
  });

  test('runtime API exposes lifecycle and binary bridge messages', () async {
    final platform = MockRufletRuntimePlatform();
    RufletRuntimePlatform.instance = platform;

    final started = await RufletRuntime.start(
      projectRoot: '/tmp/demo',
      entrypoint: '/tmp/demo/main.mrb',
    );
    expect(started.running, true);
    expect(started.port, 8550);
    expect((await RufletRuntime.status()).error, '');
    expect((await RufletRuntime.serverUrl()).scheme, 'inprocess');
    await RufletRuntime.sendToRuby(Uint8List.fromList([1, 2, 3]));
    expect(platform.sentMessage, [1, 2, 3]);
    expect(await RufletRuntime.receiveFromRuby(), [4, 5, 6]);
    await RufletRuntime.closeBridge();
    await RufletRuntime.stop();
  });
}
