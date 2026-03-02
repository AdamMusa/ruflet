# ruflet_client

Ruflet Flutter client template (mobile, desktop, web).

## What is included

- Ruflet/Flet client bootstrap and QR/manual connect flow.
- Flet client bootstrap and QR/manual connect flow.

## Run client template

```bash
cd ruflet_client
flutter pub get
flutter run
```

For desktop or web testing:

```bash
flutter run -d macos
flutter run -d chrome
```

## Run with Ruflet demo app

1. Start a Ruflet backend demo app:

```bash
cd ../examples
bundle install
ruflet run main.rb
```

2. Start this client template:

```bash
cd ../ruflet_client
flutter run
```

3. Connect from client:

- Mobile: scan QR from `ruflet run ...` output or enter URL manually.
- Desktop/Web: opens and targets local backend URL automatically.
