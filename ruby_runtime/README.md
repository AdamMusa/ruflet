# ruby_runtime

`ruby_runtime` is the native Ruflet server runtime for self-contained Flutter
apps. This package contains the compact mruby (`--lite`) engine and is
deliberately not a general-purpose Ruby plugin.

A `--full` build uses a separate, target-specific package with the same Flutter
package name and API. That distribution declares `"engine": "cruby"` and its
supported targets in `ruflet-full-runtime.json`; the CLI will not pass this
mruby package off as a full CRuby runtime.

```json
{
  "engine": "cruby",
  "ruby_version": "4.0.5",
  "platforms": ["android"],
  "gem_packager": "tool/package_gems"
}
```

The manifest is target-specific. The CRuby builders currently included in this
repository produce and test separate Android and macOS distributions.

`gem_packager` is optional for a host-compatible desktop runtime. Cross-target
mobile distributions should provide it so native gem extensions are built for
the target. Ruflet calls it with `--gemfile`, `--lockfile`, `--path`, and
`--platform`; the resulting Bundler tree is placed under `vendor/bundle` in the
packaged project.

## Runtime Contract

The runtime has three inputs:

- `vm/bootstrap.rb` provides framework-neutral loading and compatibility support.
- Ruflet framework and server gems are precompiled into the VM distribution.
- `main.rb` (or a build-produced `main.mrb`) is the application's entrypoint.

At startup the native plugin initializes mruby, installs the generic bootstrap,
initializes the preloaded gems, and executes the entrypoint. The application
loads Ruflet normally with `require`; Ruflet's gems own the protocol and all
framework behavior.

Every self-contained native application exchanges the binary Ruflet protocol
through an in-process native queue on Android, iOS, macOS, Linux, and Windows.
It does not bind a loopback port or create an HTTP or WebSocket connection. The
renderer receives
`inprocess://embedded`, which is a transport endpoint rather than a network
URL. WebSockets remain the transport for an explicitly external Ruflet or Rails
server. These are separate contracts: an unavailable in-process bridge is an
error, not a signal to fall back to networking.

The lite device runtime can execute packaged Ruby source or mruby bytecode. It
does not compile gems or resolve dependencies on-device; `ruflet build --lite`
packages the developer's application code and assets. The legacy `--self` flag
selects the same profile.

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
final endpoint = await RufletRuntime.serverUrl();
await RufletRuntime.stop();
```

`RufletRuntimeStatus` reports whether the VM is running and the last startup or
runtime error. In a self-contained native application, `serverUrl()` returns
the transport endpoint `inprocess://embedded`. The name is retained for API
compatibility; it does not imply that a network server exists. The binary
`sendToRuby()` and `receiveFromRuby()` APIs carry protocol frames between the
native renderer and the embedded VM.

## Build Flow

`ruflet build --lite`:

1. Copies the entrypoint, `lib/`, and non-secret runtime assets.
2. Compiles each Ruby file to matching `.mrb` bytecode when a compatible
   `mrbc` is available, preserving `require_relative` paths.
3. Writes a content-addressed runtime manifest and packages that tree.
4. Builds the Flutter client with the resolved `ruby_runtime` dependency. The
   package already contains every native VM binary; the application build does
   not compile mruby or Ruflet gems.

The runtime is intentionally scoped to Ruflet. Applications needing an
external CRuby process can use Ruflet's server-driven mode. Self-contained
applications that need CRuby and their locked project gems use `--full` with a
full runtime distribution.

## Startup

Self-contained apps start the VM alongside the Flutter engine rather than
waiting for Dart. Apple begins at dynamic-library load, Android uses an
`androidx.startup` initializer before `Application.onCreate`, and Linux/Windows
start during plugin registration. Android reuses an install-keyed extracted
project after the first launch; the other native platforms read Flutter's
bundled files directly. A content-addressed `.ruflet-runtime.json` lets full
runtime distributions apply the same no-repeat-work rule to project gems.
