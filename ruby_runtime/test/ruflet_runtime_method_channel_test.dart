import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruby_runtime/ruflet_runtime_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelRufletRuntime();
  const channel = MethodChannel('ruflet_runtime');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'stop' || call.method == 'bridgeClose')
            return null;
          if (call.method == 'bridgeSend') return null;
          if (call.method == 'bridgeReceive') {
            return Uint8List.fromList([7, 8, 9]);
          }
          if (call.method == 'serverUrl') {
            return <Object?, Object?>{'url': 'inprocess://embedded'};
          }
          return <Object?, Object?>{'running': true, 'port': 8550, 'error': ''};
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('start sends the complete Ruflet project contract', () async {
    final status = await platform.start(
      projectRoot: '/tmp/demo',
      entrypoint: '/tmp/demo/main.mrb',
      loadPaths: const ['/tmp/demo/vendor/ruflet_core/lib'],
      environment: const {'APP_ENV': 'embedded'},
      errorFilePath: '/tmp/demo/runtime.error',
      stopSignalPath: '/tmp/demo/server.stop',
    );

    expect(status.running, true);
    expect(status.port, 8550);
    expect(calls.single.method, 'start');
    expect(calls.single.arguments, {
      'projectRoot': '/tmp/demo',
      'entrypoint': '/tmp/demo/main.mrb',
      'loadPaths': ['/tmp/demo/vendor/ruflet_core/lib'],
      'environment': {'APP_ENV': 'embedded'},
      'errorFilePath': '/tmp/demo/runtime.error',
      'stopSignalPath': '/tmp/demo/server.stop',
    });
  });

  test('status and stop use Ruflet lifecycle methods', () async {
    expect((await platform.status()).port, 8550);
    await platform.stop();
    expect(calls.map((call) => call.method), ['status', 'stop']);
  });

  test('serverUrl uses the platform-owned embedded runtime endpoint', () async {
    expect((await platform.serverUrl()).toString(), 'inprocess://embedded');
    expect(calls.single.method, 'serverUrl');
  });

  test('bridge methods preserve binary protocol frames', () async {
    await platform.sendToRuby(Uint8List.fromList([1, 2, 3]));
    expect(await platform.receiveFromRuby(), [7, 8, 9]);
    await platform.closeBridge();

    expect(calls.map((call) => call.method), [
      'bridgeSend',
      'bridgeReceive',
      'bridgeClose',
    ]);
    expect(calls.first.arguments, isA<Uint8List>());
    expect(calls.first.arguments, [1, 2, 3]);
  });
}
