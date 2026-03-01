import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruby_runtime/ruby_runtime_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelRubyRuntime();
  const channel = MethodChannel('ruby_runtime');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'eval':
              return 'ok-eval';
            case 'runFile':
              return 'ok-file';
            case 'reset':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('eval', () async {
    expect(await platform.eval('1+1'), 'ok-eval');
  });

  test('runFile', () async {
    expect(await platform.runFile('/tmp/a.rb'), 'ok-file');
  });

  test('reset', () async {
    await platform.reset();
  });
}
