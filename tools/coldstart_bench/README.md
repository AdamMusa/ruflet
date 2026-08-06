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

## Flutter harness

`flutter_harness/main_real_app.dart` measures a real application's cold start
end to end. Drop it into a Flutter app that depends on `ruby_runtime` by path
and package a Ruby project under `assets/demo/`.

It does not stop at "the server bound a port", which is not the same as "the
app works": it opens the Ruflet WebSocket and sends `register_client`, which
the server answers only after running the whole application block and building
its page. The reply is proof the packaged Ruby app really started and rendered,
and `page_patch_bytes` is the size of the UI it produced.

`runApp` is called before anything about the VM is awaited, so `first_frame` is
independent of VM boot — that independence is itself one of the things being
measured.

Two startup designs, chosen with `--dart-define=COLDBENCH_MODE=`:

- `dart` — today's: extract the project out of the asset bundle, call
  `RufletRuntime.start`, poll for the port file.
- `autostart` — the platform booted the VM from `+load`; ask `serverUrl()`.

They are mutually exclusive, because the VM boots once per process. Flip
`RufletRuntimeAutostart` to match with `set_autostart.sh`; `run_matrix.sh` runs
the whole grid.

The macOS Runner also needs `com.apple.security.network.server` in its
entitlements, or the embedded server cannot bind and the harness times out.

## What these measured

macOS arm64, the real `RufletApp/demo` project (24 files, the quantum-particle
simulation), medians of 8 cold starts, timed from the plugin's dylib load —
which happens before the Flutter engine exists. Every run produced an identical
27,307-byte page patch, so all four configurations really rendered the app.

| VM | Startup design | first frame | server bound | **page rendered** |
| --- | --- | --- | --- | --- |
| icons at VM open (today) | Dart-driven (today) | 191.5 ms | 565.7 ms | **610.0 ms** |
| icons at VM open | platform autostart | 187.6 ms | 379.9 ms | **434.7 ms** |
| icons on demand | Dart-driven | 190.3 ms | 242.5 ms | **289.3 ms** |
| icons on demand | platform autostart | 200.4 ms | 201.8 ms | **242.0 ms** |

Deferring the icon tables is worth ~321 ms; starting the VM from the platform
layer is worth ~175 ms on its own but only ~47 ms once the icon tables are
deferred, because it can only hide as much Ruby boot as there is Ruby boot.

The first frame holds at ~190 ms across all four, while page-rendered moves by
368 ms — Flutter never waits on the VM. If a change ever makes the first frame
track VM boot time, something has started awaiting the runtime before `runApp`.
