# Ruflet Flutter Template

This template is used by the Ruflet build pipeline to produce self-contained or
server-driven Flutter clients.

## Entry Points

- `lib/main.self.dart` starts the embedded Ruby runtime and bundled `assets/main.rb`.
- `lib/main.server.dart` connects to an external Ruflet backend.
- `RUFLET_BACKEND_URL` overrides the backend URL for a server-driven client.

Run the template directly while developing the build pipeline:

```bash
flutter pub get
flutter run -t lib/main.self.dart
flutter run -t lib/main.server.dart \
  --dart-define=RUFLET_BACKEND_URL=http://127.0.0.1:8550
```

Application developers normally build through the Ruflet CLI:

```bash
bundle exec ruflet build apk --self
bundle exec ruflet build ios --self
bundle exec ruflet build apk
bundle exec ruflet build ios
```

`--self` packages the Ruby runtime and application with the native client.
Without it, the client connects to a separately running Ruflet backend.
