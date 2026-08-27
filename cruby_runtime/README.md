# Ruflet full CRuby runtime

This directory contains the native CRuby adapter and distribution builders
used by `ruflet build --self --full`. The generated Flutter plugin keeps the
same `ruby_runtime` package name and C ABI as the bundled lite mruby runtime,
so the generated client does not need a second integration path.

Build a local universal macOS distribution:

```sh
ruby cruby_runtime/tool/build_macos.rb
```

Build an Android distribution containing ARMv7, ARM64, and x86-64:

```sh
ruby cruby_runtime/tool/build_android.rb
```

Build a physical-device ARM64 iOS distribution:

```sh
ruby cruby_runtime/tool/build_ios.rb
```

The command prints the generated package path. Point
`RUFLET_FULL_RUNTIME_PATH` at that directory, or pass it as
`build.full_runtime_path` in Ruflet's configuration.

The full profile packages `Gemfile.lock` into `vendor/bundle`. At runtime the
adapter adds only that locked bundle's `lib` and native-extension directories
to CRuby's load path before loading `main.rb`.

Both builders download the pinned official CRuby source and verify its
checksum. macOS creates ARM64 and x86-64 slices with a macOS 11 deployment
target. Android cross-compiles CRuby with the installed NDK at API 24 and
packages only per-ABI native libraries plus one shared standard library.
Build products are cached below `build/cruby_runtime`; subsequent distribution
builds only assemble the package. The current iOS distribution is device-only;
simulator slices, Linux, and Windows are not claimed until their CRuby binaries
and gem packagers are actually cross-built and tested.
