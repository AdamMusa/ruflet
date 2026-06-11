# ruby_runtime

`ruby_runtime` is the Flutter plugin that embeds Ruflet's mruby runtime inside your app.

It is designed for self-contained Ruflet apps that ship a Ruby entry file with the client and start the backend locally on the device, instead of requiring an external Ruby server.

## Platforms

- Android
- iOS
- macOS

## What It Supports

The embedded runtime is a general-purpose mruby VM. It vendors the standard
mruby extension gems, so app code written against everyday Ruby works out of
the box:

- Ruby script evaluation with mruby (`eval`, `instance_eval` with strings)
- Running Ruby files from local storage
- File, IO, `Dir`, and socket support
- Ruflet's embedded HTTP and WebSocket server flow
- `Time` (with pure-Ruby `strftime`/`iso8601`), `Math`, `Random`/`srand`
- `Struct`, `Data.define`, `Set`, `Comparable#clamp`
- `Enumerator` (including external iteration and `lazy`), `Fiber`
- The full `*-ext` method gems: `Array`, `Hash`, `String`, `Numeric`,
  `Object`, `Kernel`, `Range`, `Symbol`, `Proc`, `Class` extensions
- `Method`/`UnboundMethod` objects, `catch`/`throw`
- JSON parse **and** generate (`JSON.generate`, `#to_json`)
- `StringIO`, `OpenStruct`, `Forwardable`, `Base64`, `SecureRandom`
  (including `uuid`), `FileUtils`, `Digest::SHA1`, real `Kernel#sleep`
- `Regexp` and `MatchData` via a pure-Ruby engine: regex literals,
  `String#match/match?/=~/scan/gsub/sub/split/[]/partition/index` with
  regexps, named captures, lookahead, backreferences, `i m x` options,
  `case ... when /re/`, `Regexp.escape/union/last_match`, `$~`

A desktop test harness compiles the exact same sources the plugins ship, so
the runtime can be exercised without booting Flutter:

```sh
tools/embedded_vm_harness/build.sh
tools/embedded_vm_harness/build/embedded_mruby --preload \
  tools/embedded_vm_harness/tests/compat_test.rb
```

In practice, this means Ruflet apps can:

- boot a local Ruby entry file such as `main.rb`
- open a local TCP server
- serve the Ruflet page endpoint over HTTP/WebSocket
- communicate with the Flutter client without an external backend

## What It Does Not Guarantee

This package uses `mruby`, not full CRuby.

Do not assume the full Ruby standard library or arbitrary Ruby gems are available. In particular, you should not rely on things like:

- advanced `Regexp` features: the embedded engine is byte-oriented (ASCII
  case folding), and lookbehind, unicode property classes (`\p{...}`), and
  the read-only `$1`..`$9` globals are not supported (use
  `Regexp.last_match(1)` or `match[1]`)
- `Date` / `DateTime` (use `Time`)
- real threads — `Thread` and `Mutex` are cooperative fakes; the embedded
  server is single-threaded
- `URI`, `Rational`, `Complex`, `Marshal`, `ObjectSpace`
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
- `RubyRuntime.serverPort()`
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
  ruby_runtime: ^0.0.4
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
  The server binds the first free port (starting at 8550) and reports the
  actual port through `serverPort()`, which returns 0 until the server has
  bound a port.
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
