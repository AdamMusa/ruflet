# Cold-start benchmarks

Measures where an embedded-Ruflet application's startup time goes, against the
same prebuilt VM archive an application links.

## Native benchmarks

```sh
sh tools/coldstart_bench/build.sh
sh tools/coldstart_bench/run_bench.sh <project_root> <project_root>/main.rb 10
```

- `bench_vm` drives `ruflet_vm_start` exactly as the plugins do and times
  start → the Ruby server binding its port.
- `bench_phases` splits the boot into `mrb_open`, the bootstrap irep and
  `require "ruflet"`.
- `bench_features` attributes framework boot cost to individual framework
  files, using the feature list `profile_framework.rb` emits.

These need mruby's headers and a build tree; point them at a checkout with
`ruby_runtime/third_party/mruby` populated.

## Flutter harnesses

`flutter_harness/` holds the two `main.dart` variants used to compare startup
designs. Drop one into a Flutter app that depends on `ruby_runtime` by path,
package a Ruby project under `assets/`, and build for macOS.

- `main_dart_driven.dart` — today's design: extract the packaged project out of
  the asset bundle, call `RufletRuntime.start`, poll for the port file.
- `main_nonblocking.dart` — platform autostart: `runApp` immediately, then let
  `RufletRuntime.serverUrl()` resolve into the widget tree.

Both print one `COLDBENCH` line per run and exit, so
`run_app_bench.sh <app-binary> <iterations>` can summarize a distribution.

The macOS Runner needs `com.apple.security.network.server` in its entitlements,
or the embedded server cannot bind and the harness times out. Autostart also
needs `RufletRuntimeAutostart` set in `Info.plist`.

## What these measured

macOS arm64, demo payload, medians of 8–10 cold starts, timed from the plugin's
dylib load (which happens before the Flutter engine exists):

| | Dart-driven start | Platform autostart |
| --- | --- | --- |
| Icon tables built at VM open | 555 ms | 394 ms |
| Icon tables built on demand | 233 ms | 191 ms |

`main_nonblocking.dart` additionally checks that Flutter does not wait on the
VM. Swapping a VM that binds in ~23 ms for one that takes ~350 ms moved the
URL's arrival by 188 ms and the first frame by 0.8 ms:

| VM | first frame | URL ready |
| --- | --- | --- |
| ~23 ms boot | 188.5 ms | 190.8 ms |
| ~350 ms boot | 189.3 ms | 378.7 ms |

If a change ever makes the first frame track the VM's boot time, something has
started awaiting `serverUrl()` before `runApp`.
