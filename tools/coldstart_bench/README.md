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

## Verifying a built application

`verify_app.py <App.app>` launches a real built client, finds the port its
embedded server bound, and performs the same register handshake. Use it to
check a shipped `.app` rather than a purpose-built harness.

## What these measured

Two sets of numbers, and the difference between them matters.

### The real client

`RufletApp/demo` (the quantum-particle simulation) built with
`flutter build macos --release --target lib/main.self.dart`, i.e. the full
80MB client with its Flet extensions. Medians of 5–6 runs after a warmup,
timed from process spawn. Every run returned an identical 27,307-byte page
patch, so all four configurations really rendered the app.

| VM | Startup design | server bound | **page rendered** |
| --- | --- | --- | --- |
| icons at VM open | Dart-driven | 626 ms | **762 ms** ← ships today |
| icons at VM open | platform autostart | 473 ms | **550 ms** |
| icons on demand | Dart-driven | 306 ms | **443 ms** |
| icons on demand | platform autostart | 85 ms | **130 ms** |

762 ms → 130 ms, a 5.9x improvement. Deferring the icon tables is worth
~319 ms; starting the VM from the platform layer is worth ~212 ms on its own
and still ~313 ms after the icon fix.

### Time to the UI, in the real client

The table above measures when the *server* can render a page. This measures when
the *application* gets there, which is the number a user feels. Both startup
designs are instrumented identically and timestamped on the platform timeline,
which starts before the Flutter engine exists:

- `extensions_ready` — Dart main has initialized the Flet extensions
- `url_ready` — the app knows where its embedded server is
- `flet_app_frame` — the frame that mounts FletApp has been painted

macOS, medians of 8 cold starts:

| VM | Startup design | extensions_ready | url_ready | **flet_app_frame** |
| --- | --- | --- | --- | --- |
| icons at VM open | Dart-driven | 213.9 ms | 574.2 ms | **579.4 ms** ← ships today |
| icons at VM open | autostart | 207.8 ms | 388.8 ms | **402.5 ms** |
| icons on demand | Dart-driven | 218.0 ms | 255.6 ms | **261.7 ms** |
| icons on demand | autostart | 209.4 ms | 213.2 ms | **224.9 ms** |

Android (API 35 emulator, icons at VM open in both — the .so has not been
rebuilt), medians of 6 cold starts, each after `pm clear` so nothing is reused:

| Startup design | extensions_ready | url_ready | **flet_app_frame** |
| --- | --- | --- | --- |
| Dart-driven | 506.7 ms | 926.6 ms | **932.1 ms** |
| autostart | 508.0 ms | 524.6 ms | **551.8 ms** |

The gap between `extensions_ready` and `url_ready` is the whole story: it is the
runtime sitting on the critical path. Dart-driven leaves 360 ms of it on macOS
and 420 ms on Android. Autostart closes it to 4 ms and 17 ms — the runtime stops
being the bottleneck and Flutter's own startup becomes the floor.

`flet_app_frame` is when FletApp mounts, not when the page is on screen; the
WebSocket register round-trip (~40–55 ms) follows, and both designs pay it
equally, so the deltas hold.

### A minimal harness, for contrast

The same measurement with `flutter_harness/main_real_app.dart` — one Flutter
app with no extensions — put autostart's marginal value at only ~47 ms.

The gap is the point: autostart hides the application's startup prologue, and a
minimal app barely has one. The real client initializes a dozen Flet extensions
and extracts its project out of the asset bundle before it ever calls `start`,
which is why the platform gets so much further ahead. Benchmark autostart
against a real client, not a toy.

The first frame holds at ~190 ms regardless of how slow the VM is, in every
configuration — Flutter never waits on the VM. If a change ever makes the first
frame track VM boot time, something has started awaiting the runtime before
`runApp`.

`client_patch/main.self.autostart.diff` is the change to the client entrypoint
these numbers came from: drop the extract-and-start block, go straight to
`runApp`, and resolve `serverUrl()` inside the widget tree.
