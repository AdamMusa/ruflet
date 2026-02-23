# Creating a New RubyNative App

## 1) Create app skeleton

From the RubyNative project root:

```bash
cd /Users/macbookpro/Documents/Izeesoft/FlutterApp/ruby_native
ruby bin/ruby_native new my_app
```

This creates:

- `my_app/main.rb`
- `my_app/Gemfile`
- `my_app/README.md`

## 2) Install dependencies in the new app

```bash
cd my_app
bundle install
```

## 3) Run your app

```bash
bundle exec ruby_native run main
```

You can also run without a script name (defaults to `main`):

```bash
bundle exec ruby_native run
```

## 4) Run Flutter client

In another terminal:

```bash
cd /Users/macbookpro/Documents/Izeesoft/FlutterApp/ruby_native/ruby_native_client
flutter run
```

## 5) Choose target mode

```bash
bundle exec ruby_native run main --mobile
bundle exec ruby_native run main --web
bundle exec ruby_native run main --desktop
```

`--mobile` is default.

## 6) Build binaries

Run from RubyNative root (or set `RUBY_NATIVE_CLIENT_DIR`):

```bash
bundle exec ruby_native build apk
bundle exec ruby_native build ios
bundle exec ruby_native build web
bundle exec ruby_native build macos
bundle exec ruby_native build windows
bundle exec ruby_native build linux
```
