# ruby_runtime

`ruby_runtime` is the native Ruflet server runtime for self-contained Flutter
apps. It is deliberately not a general-purpose Ruby plugin.

## Runtime Contract

The runtime has three inputs:

- `vm/bootstrap.rb` provides framework-neutral loading and compatibility support.
- Ruflet framework and server gems are precompiled into the VM distribution.
- `main.rb` (or a build-produced `main.mrb`) is the application's entrypoint.

At startup the native plugin initializes mruby, installs the generic bootstrap,
initializes the preloaded gems, and executes the entrypoint. The application
loads Ruflet normally with `require`; Ruflet's gems own the
HTTP/WebSocket server and all framework behavior. The Flutter client connects
to that server and renders Ruflet protocol messages.

The device runtime can execute packaged Ruby source or mruby bytecode. It does
not compile gems or resolve dependencies on-device; `ruflet build --self`
packages only the developer's application code and assets.

## Platforms

- Android
- iOS
- macOS

## Dart API

```dart
import 'package:ruby_runtime/ruflet_runtime.dart';

final status = await RufletRuntime.start(
  projectRoot: extractedProject.path,
  entrypoint: '${extractedProject.path}/main.rb',
  loadPaths: packagedGemLibDirectories,
);

final current = await RufletRuntime.status();
await RufletRuntime.stop();
```

`RufletRuntimeStatus` reports whether the VM is running and the last startup or
runtime error. The application/framework configuration determines its server
address.

## Build Flow

`ruflet build --self`:

1. Bundles `require_relative` application files into one source unit.
2. Compiles that unit to `main.mrb` with the vendored `mrbc`.
3. Packages `main.mrb` and non-Ruby project assets into the Flutter app.
4. Builds the Flutter client with the local `ruby_runtime` package.

The runtime is intentionally scoped to Ruflet. Applications needing an
external CRuby process or arbitrary gems should use Ruflet's server-driven
mode instead.
