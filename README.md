# RubyNative

RubyNative is a Ruby port of Flet for building web, desktop, and mobile apps in Ruby.

## Package split

RubyNative is now split into packages:

- `ruby_native_protocol`: protocol layer
- `ruby_native_ui`: controls, page, widget builder, DSL
- `ruby_native_server`: runtime WebSocket server and `RubyNative.run`
- `ruby_native_cli`: CLI executable (`ruby_native`)
- `ruby_native`: umbrella compatibility package

Monorepo layout:

- `packages/ruby_native_protocol`
- `packages/ruby_native_ui`
- `packages/ruby_native_server`
- `packages/ruby_native_cli`
- `packages/ruby_native`

Entry points:

- `require "ruby_native_protocol"`
- `require "ruby_native_ui"`
- `require "ruby_native_server"`
- `require "ruby_native_cli"`
- `require "ruby_native"` (loads ui + server)

## Quick start

```bash
cd /Users/macbookpro/Documents/Izeesoft/FlutterApp/ruby_native
bundle install
```

Create a new app:

```bash
bundle exec ruby_native new my_app
cd my_app
bundle install
bundle exec ruby_native run main
```

Run Flutter client in another terminal:

```bash
cd /Users/macbookpro/Documents/Izeesoft/FlutterApp/ruby_native/ruby_native_client
flutter run
```

## CLI

```bash
ruby_native new <appname>
ruby_native run [scriptname|path] [--web|--mobile|--desktop]
ruby_native build <apk|ios|aab|web|macos|windows|linux>
```

In app projects, run CLI through Bundler:

```bash
bundle exec ruby_native run
```

By default `ruby_native build ...` looks for the Flutter client at `./ruby_native_client`.
Set `RUBY_NATIVE_CLIENT_DIR` to override.

## Documentation

- New app guide: `docs/creating_new_app.md`
- Widget guide: `docs/widgets.md`
- Example apps: `/Users/macbookpro/Documents/Izeesoft/FlutterApp/ruby_native/example/main.rb`, `/Users/macbookpro/Documents/Izeesoft/FlutterApp/ruby_native/example/solitaire.rb`


<!-- If you want, I can now add Flet-style helpers for more controls next (stack, list_view, tabs, etc.) using the same generic approach. -->
