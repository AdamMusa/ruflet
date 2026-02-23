# Android Quick Guide (RubyNative)

Done in 3 steps:

## 1) Download Android app (APK)

Download the prebuilt APK artifact:

`https://github.com/AdamMusa/RubyNative/actions/runs/22304910451/artifacts/5616249668`

Unzip it and keep the APK path (example: `app-release.apk`).

## 2) Setup RubyNative CLI

From project root:

```bash
cd /Users/macbookpro/Documents/Izeesoft/FlutterApp/ruby_native
bundle install
bundle exec ruby_native --help
```

If that works, RubyNative CLI is ready.

## 3) Install APK on emulator

Start Android emulator, then:

```bash
adb devices
adb install -r /absolute/path/to/app-release.apk
```

That is it.
