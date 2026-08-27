# Self-contained runtime profiles and measurements

Ruflet has two explicit self-contained build profiles:

| Command | Engine | Application payload |
| --- | --- | --- |
| `ruflet build <target> --lite` | mruby | Precompiled project bytecode and runtime assets |
| `ruflet build <target> --full` | CRuby | `main.rb`, `Gemfile.lock`, and the locked production gem bundle |

`--self` is the compatibility spelling for `--lite`. An explicit profile wins,
so `--self --full` produces the full CRuby build. `--full` also implies
`--self`; `--lite --full` is rejected.

The CRuby distribution builders currently supplied and launch-tested in this
repository target Android and macOS. Ruflet validates the distribution manifest
against the requested target instead of silently falling back to mruby.

## Release measurements

These results were measured on 2026-08-26 with the same generated counter app,
Flutter 3.41.2, Ruby/CRuby 4.0.5, and a locked bundle containing
`ruflet_core` 0.0.21 and `ruflet_server` 0.0.21. Sizes use MiB
(`bytes / 1024 / 1024`). Launch and memory values are medians of five samples.

### Android mobile

The mobile size is the ABI-specific release APK delivered to one device. An
all-ABI AAB or simulator directory is not a per-device bundle-size result.

| Release APK | Lite mruby | Full CRuby + gems | Full overhead |
| --- | ---: | ---: | ---: |
| ARM64 | **35.39 MiB** | **38.98 MiB** | 3.59 MiB |
| ARMv7 | 31.74 MiB | 36.69 MiB | 4.95 MiB |
| x86-64 | 36.91 MiB | 40.23 MiB | 3.32 MiB |

The clean ARM64 lite APK is 37,109,405 bytes. Its Ruflet application is a
1,017-byte `main.mrb`; it contains no `main.rb`, vendored gems, or CRuby
standard library. The ARM64 full APK is 40,868,620 bytes and contains the real
CRuby runtime, `main.rb`, and the locked `vendor/bundle` tree.

Measurements used an API 35 ARM64 emulator. “Warm new process” force-stops the
app between samples while retaining installed/extracted files and OS caches;
it therefore includes VM boot but excludes first-install extraction.

| Android ARM64 metric | Lite mruby | Full CRuby + gems | Difference |
| --- | ---: | ---: | ---: |
| Embedded runtime ready, warm new process | 425 ms | **126 ms** | Full is 299 ms faster |
| Android Activity ready, warm new process | **521 ms** | 552 ms | Full is 31 ms slower |
| Activity ready, hot resume with VM retained | **62 ms** | 64 ms | +2 ms |
| Steady proportional set size (PSS) | **112.72 MiB** | 119.67 MiB | +6.95 MiB |
| Steady resident set size (RSS) | **197.97 MiB** | 204.90 MiB | +6.93 MiB |

The first launch after a clean install measured 576 ms Activity / 469 ms
runtime for lite and 1,020 ms Activity / 592 ms runtime for full. Full performs
119 ms of one-time project and gem extraction on that launch; subsequent warm
launches measured 0–2 ms for the same step.

### macOS desktop

Both release apps contain universal native runtime binaries. The ZIP column is
the transport-size comparison; the app column is the uncompressed bundle.

| macOS release metric | Lite mruby | Full CRuby + gems | Full overhead |
| --- | ---: | ---: | ---: |
| App bundle | **80.14 MiB** | 92.21 MiB | +12.07 MiB |
| ZIP | **31.18 MiB** | 36.44 MiB | +5.26 MiB |
| Visible warm launch | 592.2 ms | **412.1 ms** | Full is 180.1 ms faster |
| Steady RSS | **136.38 MiB** | 144.97 MiB | +8.59 MiB |

The full macOS bundle includes a 14.74 MiB universal `libruby.4.0.dylib` plus
the CRuby standard library. Compression reduces the shipping-size difference
to 5.26 MiB.

## Reproduce the two builds

Build the native CRuby distributions once:

```bash
ruby cruby_runtime/tool/build_android.rb
ruby cruby_runtime/tool/build_macos.rb
```

Then build the same project in both profiles:

```bash
ruflet build apk --self --split-per-abi --release
RUFLET_FULL_RUNTIME_PATH=build/cruby_runtime/android \
  ruflet build apk --self --full --split-per-abi --release

ruflet build macos --self --release
RUFLET_FULL_RUNTIME_PATH=build/cruby_runtime/macos-universal \
  ruflet build macos --self --full --release
```

The build pipeline clears profile-sensitive generated Flutter/Gradle asset
outputs before packaging. This prevents a preceding full build from inflating
a later lite APK with stale `vendor/bundle` files, and prevents lite bytecode
from leaking into a full build.
