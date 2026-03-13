# Ruflet

Ruflet is a Ruby port of [Flet](https://flet.dev/) for building web, desktop, and mobile apps in Ruby.

Ruflet supports both class-based apps and `Ruflet.run do |page| ... end`.
The generated scaffold uses `Ruflet.run`.

## Start Here

1. Install mobile client app from releases:
- [Ruflet Releases](https://github.com/AdamMusa/Ruflet/releases)
- Install latest Android APK or iOS build.

2. Install Ruflet from RubyGems:

```bash
gem install ruflet
```

3. Create and run your first app:

```bash
ruflet new my_app
cd my_app
bundle install
ruflet run main.rb
```

4. Open Ruflet mobile client and connect:
- Enter URL manually, or
- Tap `Scan QR` and scan QR shown by `ruflet run ...`

## Package Split

Ruflet is split into packages:

- `ruflet`: umbrella install (pulls in core runtime, server, and CLI)
- `ruflet_core`: core runtime implementation (protocol + UI)
- `ruflet_server`: WebSocket runtime (`Ruflet.run` backend)
- `ruflet_cli`: CLI executable (`ruflet`)
- `ruflet_rails`: Rails integration/protocol adapter

Monorepo folders:

- `packages/ruflet`
- `packages/ruflet_server`
- `packages/ruflet_cli`
- `packages/ruflet_rails`

## New Project Behavior

`ruflet new <appname>` generates a `Gemfile` with just `gem "ruflet"`, and the umbrella gem pulls in the matching core runtime, server runtime, and CLI version.

## App Style (Required in docs/examples)

Use the current scaffold style:

```ruby
require "ruflet"

Ruflet.run do |page|
  page.title = "Counter Demo"
  count = 0
  count_text = text(count.to_s, size: 40)

  page.add(
    container(
      expand: true,
      alignment: Ruflet::MainAxisAlignment::CENTER,
      content: column(
        alignment: Ruflet::MainAxisAlignment::CENTER,
        horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
        children: [
          text("You have pushed the button this many times:"),
          count_text
        ]
      )
    ),
    floating_action_button: fab(
      icon: Ruflet::MaterialIcons::ADD,
      on_click: ->(_e) do
        count += 1
        page.update(count_text, value: count.to_s)
      end
    )
  )
end
```

Widget builders are global/free helpers (`text`, `row`, `column`, `container`, etc.).
Use `page` only for runtime/page operations (`add`, `update`, `go`, `show_dialog`, `pop_dialog`).

## CLI

```bash
ruflet new <appname>
ruflet run [scriptname|path] [--web|--desktop] [--port PORT]
ruflet update [web|desktop|all] [--check] [--force] [--platform PLATFORM]
ruflet build <apk|ios|aab|web|macos|windows|linux>
```

For monorepo development (always uses local CLI source), run:

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
- Example apps: [main.rb](examples/main.rb), [solitaire.rb](examples/solitaire.rb), [calculator.rb](examples/calculator.rb)
