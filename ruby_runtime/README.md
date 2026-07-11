# ruby_runtime

`ruby_runtime` is the native Ruflet server runtime for self-contained Flutter
apps. It is deliberately not a general-purpose Ruby plugin.

## Runtime Contract

The build pipeline produces two bytecode artifacts:

- `embedded_ruflet_runtime.h` contains Ruflet framework and server code.
- `main.mrb` contains the application's bundled Ruby entrypoint.

At startup the native plugin loads the Ruflet runtime, loads `main.mrb`, and
runs the local HTTP/WebSocket server. The Flutter client connects to that
server and renders Ruflet protocol messages.

The device runtime does not expose Ruby source evaluation, file execution, or
compiler APIs. Ruby compilation happens during `ruflet build --self`.

## Platforms

- Android
- iOS
- macOS

## Dart API

```dart
import 'package:ruby_runtime/ruflet_runtime.dart';

final status = await RufletRuntime.start(
  projectRoot: extractedProject.path,
  entrypoint: '${extractedProject.path}/main.mrb',
);

final current = await RufletRuntime.status();
await RufletRuntime.stop();
```

`RufletRuntimeStatus` reports whether the server is running, its port, and the
last startup or runtime error.

## Build Flow

`ruflet build --self`:

1. Bundles `require_relative` application files into one source unit.
2. Compiles that unit to `main.mrb` with the vendored `mrbc`.
3. Packages `main.mrb` and non-Ruby project assets into the Flutter app.
4. Builds the Flutter client with the local `ruby_runtime` package.

The runtime is intentionally scoped to Ruflet. Applications needing an
external CRuby process or arbitrary gems should use Ruflet's server-driven
mode instead.
