## 0.0.12

- Every platform plugin now bridges to the same four `ruflet_vm_*` entry points
  in the prebuilt VM. iOS and macOS previously drove mruby themselves and
  carried their own copy of the bootstrap and host logic, so the plugin and the
  VM could drift apart -- and the shipped Linux and Windows libraries had
  already broken that way. Releasing a runtime is now replacing the built
  artifact, nothing else.
- Drop the vendored mruby sources, Onigmo and host build outputs from the iOS
  and macOS folders. Nothing compiles them any more: the bridge needs only
  ruflet_vm_host.h.
- Fix `Ruflet::Server#web_client_root`, which used `defined?(@ivar)`. The
  embedded VM has no `defined?` keyword, so it parsed as a method call and
  every HTTP request raised NoMethodError on device.
- Rebuild every VM artifact from current framework sources.

## 0.0.11

- Fix the Linux and Windows VM libraries. 0.0.10 rebuilt them from the mruby
  archive alone, which dropped the host layer the desktop plugins link
  against: `ruflet_vm_start`, `ruflet_vm_stop`, `ruflet_vm_is_running`,
  `ruflet_vm_copy_error`, and the embedded bootstrap bytecode. A Linux or
  Windows build failed at link time with undefined references. Both are now
  built from the mruby archive plus `desktop/ruflet_vm_host.cpp`, exporting
  the same API as before. iOS, macOS and Android were unaffected -- their
  plugins compile the host layer themselves.

## 0.0.10

- Rebuild every prebuilt VM from current framework sources: iOS device and
  simulator, Android (all four ABIs), Linux x64 and aarch64, and Windows.
  0.0.9 rebuilt only macOS, so every other platform still shipped a framework
  from before the `ruflet_app` control rename. An application calling
  `ruflet_app` serialized a control name no client registers, and a
  self-contained build rendered "Unknown control: RufletApp" on device while
  server-driven web and desktop, which serialize on the host, worked.
- Embed `ruflet_core` and `ruflet_server` 0.0.21.

## 0.0.9

- Rebuild the macOS VM from the current framework sources. The 0.0.8 artifact
  predates the `ruflet_app` control rename, so an application calling
  `ruflet_app` fell through to a control the client cannot render and failed
  silently, with no connection and no error.
- Embed `ruflet_core` and `ruflet_server` 0.0.20.

## 0.0.8

- Embed the published `ruflet_core` 0.0.19 and `ruflet_server` 0.0.19 gems in
  every prebuilt Android, iOS, macOS, Linux, and Windows VM artifact.
- Include repeatable snackbar and banner presentation fixes from Ruflet 0.0.19.
- Refresh artifact manifests and checksums so application builds continue to
  consume the packaged VM without compiling mruby in developer environments.

## 0.0.7

- Run self-contained Ruflet applications through the generic embedded mruby VM
  and preloaded Ruflet gems, using the app's normal `main.rb` entry point.
- Embed the published `ruflet_core` 0.0.18 and `ruflet_server` 0.0.18 payloads
  in prebuilt device binaries; application builds no longer compile the VM.
- Package the runtime for Android, iOS, macOS, Linux, and Windows, with dynamic
  embedded-server port discovery for multiple application instances.
- Add the runtime and protocol fixes required by current Ruflet controls,
  services, pickers, dialogs, maps, audio, Rive, charts, and SpinKit clients.
- Improve embedded runtime concurrency, callback reporting, and UI update
  performance without adding application-specific behavior to the VM.

## 0.0.6

- Update embedded Ruflet pages from client resize events so `page.width` and
  `page.height` reflect the live viewport, and expose `page.on_resize`.
- Add Linux desktop support with the complete `ruby_runtime` method-channel
  contract used by self-contained applications.

## 0.0.5

- Bind the embedded server to an available port and report the selected port to
  the client, allowing multiple packaged apps to run at the same time.
- Add the mruby compatibility surface needed by Ruflet gems, including regular
  expressions, standard extension gems, common stdlib helpers, randomness,
  clocks, and sleep support.
- Add a desktop harness that exercises the same mruby sources shipped on device.

## 0.0.4

- Add packaged Linux `aarch64`/`x86_64` and Windows `x86_64` Ruflet VMs.
- Expose the same `start`, `status`, and `stop` runtime contract on Windows and Linux.
- Rebuild the universal macOS VM with the current preloaded Ruflet gems.
- Support Flet-compatible `Page.window` through the existing Ruflet protocol without creating another VM.

## 0.0.3

- Fix native Android, iOS, and macOS includes to load the packaged embedded Ruflet runtime header from `shared/`.

## 0.0.2

- Align Android plugin packaging and publish metadata for Ruflet self-contained builds.
- Document supported runtime behavior and developer usage more clearly.
- Prepare the package for pub.dev publication from the standalone `ruby_runtime` package.

## 0.0.1

- Initial `ruby_runtime` Flutter plugin release.
- Added embedded mruby execution APIs for Ruflet.
- Added embedded file server support used by self-contained Ruflet apps.
- Added Android, iOS, and macOS platform implementations.
