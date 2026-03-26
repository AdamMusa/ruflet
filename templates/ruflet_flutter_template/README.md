# ruflet_flutter_template

Ruflet Flutter template for a self-contained Ruby-driven app or an external Ruflet backend.

## What is included

- Ruflet/Flet client bootstrap with fixed local port auto-connect (`8550`).
- Self-contained startup via `ruby_runtime` when `RUFLET_CLIENT_URL` is not set.
- Developer-editable Ruby entry file at:
  - `assets/main.rb`
- External backend override via:
  - `--dart-define=RUFLET_CLIENT_URL=http://host:8550`

## Run client template

```bash
cd ruflet_flutter_template
flutter pub get
flutter run
```

The template runs `assets/main.rb` inside the app by default, so developers can replace that file with their own Ruflet implementation.

To connect to an external backend instead:

```bash
flutter run --dart-define=RUFLET_CLIENT_URL=http://127.0.0.1:8550
```

For desktop or web testing:

```bash
flutter run -d macos
flutter run -d chrome
```
