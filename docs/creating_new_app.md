# Creating a New RubyNative App

## 1) Install CLI (one-time)

```bash
gem install specific_install
gem specific_install -l https://github.com/AdamMusa/RubyNative.git -d packages/ruby_native_cli
```

## 2) Create app

```bash
ruby_native new my_app
cd my_app
```

## 3) Install dependencies

```bash
bundle install
```

## 4) Run app server

```bash
ruby_native run main.rb
```

When running mobile target, CLI prints:
- mobile connect URL
- WebSocket URL
- QR code for scan-connect

## 5) Connect from mobile client

Install RubyNative mobile app from:
- [RubyNative Releases](https://github.com/AdamMusa/RubyNative/releases)

Then either:
- manually enter URL shown in terminal, or
- tap `Scan QR` and scan terminal QR

## 6) Target modes

```bash
ruby_native run main.rb --mobile
ruby_native run main.rb --web
ruby_native run main.rb --desktop
```

`--mobile` is default.

## 7) Build binaries

```bash
ruby_native build apk
ruby_native build ios
ruby_native build web
ruby_native build macos
ruby_native build windows
ruby_native build linux
```

## Notes

- `ruby_native new` generates app `Gemfile` pulling `ruby_native` from GitHub.
- It does not include `ruby_native_cli` in app dependencies.
