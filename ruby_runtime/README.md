# ruby_runtime

Embedded mruby runtime plugin for Flutter.

`ruby_runtime` exposes a simple Dart API:
- `RubyRuntime.initialize()`
- `RubyRuntime.eval(String code)`
- `RubyRuntime.runFile(String path)`
- `RubyRuntime.reset()`

## Usage

### 1. Initialize runtime

```dart
import 'package:ruby_runtime/ruby_runtime.dart';

Future<void> setupRuby() async {
  await RubyRuntime.initialize();
}
```

### 2. Execute Ruby code

```dart
Future<String> runCode() async {
  final result = await RubyRuntime.eval('"Hello, " + "mruby"');
  return result; // => "Hello, mruby"
}
```

### 3. Run a Ruby file

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ruby_runtime/ruby_runtime.dart';

Future<String> runRubyFile() async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/sample.rb');
  await file.writeAsString('class Calc\n  def add(a, b)\n    a + b\n  end\nend\nCalc.new.add(10, 20)');

  return RubyRuntime.runFile(file.path); // => "30"
}
```

### 4. Reset runtime (optional)

```dart
Future<void> resetRuby() async {
  await RubyRuntime.reset();
}
```

## Notes

- This runtime is mruby, not CRuby.
- Not all Ruby stdlib APIs are available by default.
- Socket/IO support is provided via mruby gems included in the plugin.
