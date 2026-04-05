# ruby_runtime

`ruby_runtime` is the Flutter plugin that embeds Ruflet's mruby runtime inside your app.

It is designed for self-contained Ruflet apps that ship a Ruby entry file with the client and start the backend locally on the device, instead of requiring an external Ruby server.

## Platforms

- Android
- iOS
- macOS

## What It Supports

The embedded runtime includes the pieces Ruflet needs for local execution:

- Ruby script evaluation with mruby
- Running Ruby files from local storage
- Basic file and IO support
- Socket support
- Ruflet's embedded HTTP and WebSocket server flow
- JSON support

In practice, this means Ruflet apps can:

- boot a local Ruby entry file such as `main.rb`
- open a local TCP server
- serve the Ruflet page endpoint over HTTP/WebSocket
- communicate with the Flutter client without an external backend

## What It Does Not Guarantee

This package uses `mruby`, not full CRuby.

Do not assume the full Ruby standard library or arbitrary Ruby gems are available. In particular, you should not rely on things like:

- full `net/http`
- `webrick`
- `openssl`
- arbitrary native Ruby gems
- Bundler-based gem loading inside the embedded runtime

If your app needs the broader CRuby ecosystem, use a separate backend instead of the embedded runtime.

## Dart API

`ruby_runtime` exposes these methods:

- `RubyRuntime.initialize()`
- `RubyRuntime.eval(String code)`
- `RubyRuntime.runFile(String path)`
- `RubyRuntime.reset()`
- `RubyRuntime.startFileServer(String path, {String? stopSignalPath})`
- `RubyRuntime.stopFileServer()`
- `RubyRuntime.isFileServerRunning()`
- `RubyRuntime.lastFileServerError()`

## Recommended Ruflet Flow

For Ruflet apps, the normal embedded flow is:

1. Bundle a Ruby file in Flutter assets, usually `assets/main.rb`.
2. Copy that asset to a writable app directory at runtime.
3. Start the embedded file server with `RubyRuntime.startFileServer(...)`.
4. Point the Flutter Ruflet/Flet client to the local server URL.

This is the model used by the Ruflet Flutter template.

## Quick Start

### 1. Add the dependency

```yaml
dependencies:
  ruby_runtime: ^0.0.1
```

### 2. Import the package

```dart
import 'package:ruby_runtime/ruby_runtime.dart';
```

### 3. Initialize the runtime

```dart
Future<void> setupRuby() async {
  await RubyRuntime.initialize();
}
```

### 4. Evaluate a small Ruby expression

```dart
Future<String> runCode() async {
  return RubyRuntime.eval('"Hello from mruby"');
}
```

### 5. Run a Ruby file

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ruby_runtime/ruby_runtime.dart';

Future<String> runRubyFile() async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/sample.rb');
  await file.writeAsString('puts "hello"');
  return RubyRuntime.runFile(file.path);
}
```

## Running Ruflet Embedded

This is the simplest pattern for Ruflet developers:

```dart
final appDir = await getApplicationSupportDirectory();
final rubyFile = File('${appDir.path}/main.rb');

await rubyFile.writeAsString(rubySource);
await RubyRuntime.initialize();
await RubyRuntime.startFileServer(rubyFile.path);

final running = await RubyRuntime.isFileServerRunning();
final lastError = await RubyRuntime.lastFileServerError();
```

Notes:

- `startFileServer()` starts the embedded Ruflet runtime server in native code.
- `lastFileServerError()` is the first place to check when local startup fails.
- `reset()` is useful during development when you want a clean embedded runtime state.

## Developer Notes

If you are building on top of `ruby_runtime`, keep these constraints in mind:

- Prefer plain Ruby files over complex gem-based boot flows.
- Keep runtime code focused on Ruflet app logic and lightweight server behavior.
- Treat the embedded runtime as a targeted app runtime, not a full replacement for desktop/server Ruby.
- Test any socket or file behavior on each supported platform you care about.

## When To Use It

Use `ruby_runtime` when:

- you want a self-contained Ruflet mobile or desktop app
- your embedded Ruby code is controlled by your app
- you want the Flutter client and Ruby backend to ship together

Do not use it when:

- you need the full CRuby ecosystem
- you depend on gems that require MRI features or native extensions
- you need a general-purpose Ruby application server environment
