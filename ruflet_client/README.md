# Ruflet Client

The Ruflet client renders server-driven Ruflet applications on mobile, desktop,
and web.

## Run The Client

```bash
flutter pub get
flutter run
```

Choose a desktop or web target when needed:

```bash
flutter run -d macos
flutter run -d chrome
```

Linux WebView support uses WebKitGTK 4.1. Debian and Ubuntu development hosts
can install it with `sudo apt install libwebkit2gtk-4.1-dev`.

## Connect To An App

Start a Ruflet application in another terminal:

```bash
cd ../showcase
bundle install
bundle exec ruflet run
```

On mobile, scan the QR code printed by `ruflet run` or enter the backend URL.
Desktop and web development clients connect to the local backend automatically.

This package is the client implementation used by Ruflet builds. Application
developers normally work in a generated Ruflet project and use the Ruflet CLI
instead of editing this package.
