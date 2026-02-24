# RubyNative

RubyNative is a Ruby port of Flet for building web, desktop, and mobile apps in Ruby.

Class-based apps are the recommended and documented standard:
- `class MyApp < RubyNative::App`
- implement `def view(page)`

## Start Here

1. Install mobile client app from releases:
- [RubyNative Releases](https://github.com/AdamMusa/RubyNative/releases)
- Install latest Android APK or iOS build.

2. Install RubyNative CLI from GitHub:

```bash
gem install specific_install
gem specific_install -l https://github.com/AdamMusa/RubyNative.git -d packages/ruby_native_cli
```

3. Create and run your first app:

```bash
ruby_native new my_app
cd my_app
bundle install
ruby_native run main.rb
```

4. Open RubyNative mobile client and connect:
- Enter URL manually, or
- Tap `Scan QR` and scan QR shown by `ruby_native run ...`

## Package Split

RubyNative is split into packages:

- `ruby_native_protocol`: protocol layer
- `ruby_native_ui`: controls, page, widget builder
- `ruby_native_server`: WebSocket runtime (`RubyNative.run`)
- `ruby_native_cli`: CLI executable (`ruby_native`)
- `ruby_native`: runtime umbrella package (`ui + server + protocol`)

Monorepo folders:

- `packages/ruby_native_protocol`
- `packages/ruby_native_ui`
- `packages/ruby_native_server`
- `packages/ruby_native_cli`
- `packages/ruby_native`

## New Project Behavior

`ruby_native new <appname>` now generates a `Gemfile` that pulls `ruby_native` from GitHub (`main` branch).

It does **not** add `ruby_native_cli` to app dependencies.

That keeps CLI global/tooling-level and app deps runtime-focused.

## App Style (Required in docs/examples)

Use class-based apps:

```ruby
require "ruby_native"

class MyApp < RubyNative::App
  def view(page)
    page.vertical_alignment = RubyNative::MainAxisAlignment::CENTER
    page.horizontal_alignment = RubyNative::CrossAxisAlignment::CENTER
    page.title = "Hello"
    page.add(page.text(value: "Hello RubyNative"))
  end
end

MyApp.new.run
```

## CLI

```bash
ruby_native new <appname>
ruby_native run [scriptname|path] [--web|--mobile|--desktop]
ruby_native build <apk|ios|aab|web|macos|windows|linux>
```

By default `ruby_native build ...` looks for Flutter client at `./ruby_native_client`.
Set `RUBY_NATIVE_CLIENT_DIR` to override.

## Development (Monorepo)

```bash
cd /Users/macbookpro/Documents/Izeesoft/FlutterApp/ruby_native
/opt/homebrew/opt/ruby/bin/bundle install
```

## Documentation

- [Creating New App](docs/creating_new_app.md)
- [Widgets Guide](docs/widgets.md)
- Example apps: [main.rb](example/main.rb), [solitaire.rb](example/solitaire.rb), [calculator.rb](example/calculator.rb)
