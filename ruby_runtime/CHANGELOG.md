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
