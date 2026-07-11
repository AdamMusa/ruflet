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
          if (call.method == 'stop') return null;
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
      stopSignalPath: '/tmp/demo/server.stop',
    );

    expect(status.running, true);
    expect(status.port, 8550);
    expect(calls.single.method, 'start');
    expect(calls.single.arguments, {
      'projectRoot': '/tmp/demo',
      'entrypoint': '/tmp/demo/main.mrb',
      'stopSignalPath': '/tmp/demo/server.stop',
    });
  });

  test('status and stop use Ruflet lifecycle methods', () async {
    expect((await platform.status()).port, 8550);
    await platform.stop();
    expect(calls.map((call) => call.method), ['status', 'stop']);
  });
}
