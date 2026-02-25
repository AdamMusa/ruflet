# Ruflet

Ruflet is a Ruby port of Flet for building web, desktop, and mobile apps in Ruby.

Class-based apps are the recommended and documented standard:
- `class MyApp < Ruflet::App`
- implement `def view(page)`

## Start Here

1. Install mobile client app from releases:
- [Ruflet Releases](https://github.com/AdamMusa/Ruflet/releases)
- Install latest Android APK or iOS build.

2. Install Ruflet CLI from GitHub:

```bash
gem install specific_install
gem specific_install -l https://github.com/AdamMusa/Ruflet.git -d packages/ruflet_cli
```

3. Create and run your first app:

```bash
ruflet new my_app
cd my_app
bundle install
ruflet run main.rb
```

CLI output after creation:

```text
Ruflet app created: my_app
```

4. Open Ruflet mobile client and connect:
- Enter URL manually, or
- Tap `Scan QR` and scan QR shown by `ruflet run ...`

## Package Split

Ruflet is split into packages:

- `ruflet`: core runtime (includes protocol + UI)
- `ruflet_server`: WebSocket runtime (`Ruflet.run` backend)
- `ruflet_cli`: CLI executable (`ruflet`)
- `ruflet_rails`: Rails integration/protocol adapter

Monorepo folders:

- `packages/ruflet`
- `packages/ruflet_server`
- `packages/ruflet_cli`
- `packages/ruflet_rails`

## New Project Behavior

`ruflet new <appname>` now generates a `Gemfile` that pulls `ruflet` from GitHub (`main` branch).

It does **not** add `ruflet_cli` to app dependencies.

That keeps CLI global/tooling-level and app deps runtime-focused.

## App Style (Required in docs/examples)

Use class-based apps:

```ruby
require "ruflet"

class MyApp < Ruflet::App
  def view(page)
    page.vertical_alignment = Ruflet::MainAxisAlignment::CENTER
    page.horizontal_alignment = Ruflet::CrossAxisAlignment::CENTER
    page.title = "Hello"
    page.add(page.text(value: "Hello Ruflet"))
  end
end

MyApp.new.run
```

## CLI

```bash
ruflet new <appname>
ruflet run [scriptname|path] [--web|--mobile|--desktop]
ruflet build <apk|ios|aab|web|macos|windows|linux>
```

By default `ruflet build ...` looks for Flutter client at `./ruflet_client`.
Set `RUFLET_CLIENT_DIR` to override.

## Development (Monorepo)

```bash
cd /Users/macbookpro/Documents/Izeesoft/FlutterApp/ruflet
/opt/homebrew/opt/ruby/bin/bundle install
```

## Documentation

- [Creating New App](docs/creating_new_app.md)
- [Widgets Guide](docs/widgets.md)
- Example apps: [main.rb](example/main.rb), [solitaire.rb](example/solitaire.rb), [calculator.rb](example/calculator.rb)
