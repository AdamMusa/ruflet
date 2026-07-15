# ruflet_flutter_template

Ruflet Flutter template for self-contained and server-driven clients.

## What is included

- Ruflet/Flet client bootstrap with automatic embedded-server port discovery.
- Self-contained startup via `ruby_runtime` in `lib/main.self.dart`.
- Server-driven startup in `lib/main.server.dart`.
- Compiler-free startup from the packaged `main.mrb` artifact.
- External backend override via:
  - `--dart-define=RUFLET_BACKEND_URL=http://host:8550`

## Run client template

```bash
cd ruflet_flutter_template
flutter pub get
flutter run
```

`ruflet build --self` compiles the project's `main.rb` and packages the resulting `main.mrb` automatically.

Linux WebView builds require WebKitGTK 4.1 development files. On Debian or
Ubuntu install them with `sudo apt install libwebkit2gtk-4.1-dev`.

## Conditional extensions and native services

Application dependencies are selected from the developer project's configuration;
the generated client does not bundle every optional plugin.

```yaml
# ruflet.yaml
extensions:
  - charts
  - map
  - rive
```

Native capabilities that require Android or iOS permissions belong in a sibling
`services.yaml`. Ruflet activates their required client extensions and writes the
platform permission declarations during the build.

```yaml
# services.yaml
services:
  - camera:
      description: Capture profile photos.
  - location:
      description: Show the device location on the map.
```

The same selection is applied to server-driven and self-contained builds.

To connect to an external backend instead:

```bash
flutter run --dart-define=RUFLET_BACKEND_URL=http://127.0.0.1:8550
```

For Ruflet CLI builds:

```bash
ruflet build apk --self
ruflet build ios --self
ruflet build apk
ruflet build ios
```

- `ruflet build ... --self` builds the self-contained client with `ruby_runtime`.
- `ruflet build ...` without `--self` builds the server-driven client without `ruby_runtime`.

For desktop or web testing:

```bash
flutter run -d macos
flutter run -d chrome
```
