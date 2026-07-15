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

- Android (prebuilt `armeabi-v7a`, `arm64-v8a`, `x86`, and `x86_64` VM
  libraries are distributed in `android/src/main/jniLibs`)
- iOS (prebuilt device `arm64` and simulator `arm64`/`x86_64` VM slices are
  distributed in `ios/Frameworks/RufletVM.xcframework`; application builds
  compile only the Flutter bridge)
- macOS (the universal `arm64`/`x86_64` VM archive is distributed in
  `macos/Frameworks`; application builds compile only the Flutter bridge)
- Linux (prebuilt `aarch64` and `x86_64` VM libraries are distributed in
  `linux/lib`; application builds compile only the Flutter method-channel bridge)
- Windows (the prebuilt `x86_64` VM DLL is distributed in `windows/bin`;
  application builds compile only the Flutter method-channel bridge)

Native VM artifacts are part of the `ruby_runtime` release, not part of the
developer application build. Each artifact has a checked manifest beside it
with its platform, architectures, contents, and SHA-256 digest. Updating
mruby or a preloaded Ruflet gem creates a new runtime artifact and package
version. It does not copy framework Ruby sources into an application.

Android application builds link the packaged `libruby_runtime.so` for their
target ABI. They never read mruby's local `build/host_vm` directory and never
compile Ruflet gems while building the developer application.

Desktop application builds follow the same rule. Linux links and bundles the
packaged library selected for the host architecture. Windows bundles the
packaged DLL and loads its stable C API. The native window is the one owned by
the Flutter/Flet client; `Page.window` controls it through the normal Ruflet
protocol and does not start another VM.

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
4. Builds the Flutter client with the resolved `ruby_runtime` dependency. The
   package already contains every native VM binary; the application build does
   not compile mruby or Ruflet gems.

The runtime is intentionally scoped to Ruflet. Applications needing an
external CRuby process or arbitrary gems should use Ruflet's server-driven
mode instead.
