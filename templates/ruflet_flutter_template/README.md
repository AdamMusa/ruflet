# ruflet_flutter_template

Ruflet Flutter client template (mobile, desktop, web) using a built-in Dart manifest server.

## What is included

- Ruflet/Flet client bootstrap with fixed local port auto-connect (`8550`).
- Built-in lightweight WebSocket backend in Dart.
- Manifest-driven UI payload from:
  - `assets/ruflet_demo_app/manifest.json`

## Run client template

```bash
cd ruflet_flutter_template
flutter pub get
flutter run
```

For desktop or web testing:

```bash
flutter run -d macos
flutter run -d chrome
```

The client auto-targets local backend port `8550`. No Ruby runtime is required.
