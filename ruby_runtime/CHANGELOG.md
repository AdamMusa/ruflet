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
