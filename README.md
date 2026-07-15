# Ruflet

Ruflet lets Ruby developers build web, desktop, and mobile interfaces with a
single Ruby UI layer.

## Quick Start

Install the CLI and create an app:

```bash
gem install ruflet
ruflet new my_app
cd my_app
bundle install
ruflet run
```

`ruflet run` starts the Ruby backend and prints a QR code for a mobile client.
Use `--web` to open the web client or `--desktop` to launch the desktop client:

```bash
ruflet run --web
ruflet run --desktop
```

## Write An App

The generated `main.rb` is the application entrypoint:

```ruby
require "ruflet"

Ruflet.run do |page|
  page.title = "Counter"
  count = 0
  value = text("0", size: 40)

  page.add(
    column(
      children: [
        value,
        button(
          "Add one",
          on_click: ->(_event) do
            count += 1
            page.update(value, value: count.to_s)
          end
        )
      ]
    )
  )
end
```

Control builders such as `text`, `button`, `row`, and `column` create the UI.
The `page` object manages application-level behavior including navigation,
dialogs, services, and updates.

## Project Files

A generated Ruflet app includes:

- `main.rb` - Ruby application entrypoint
- `ruflet.yaml` - app metadata, assets, extensions, and build settings
- `services.yaml` - protected device capabilities requested by the app
- `Gemfile` - Ruflet runtime dependencies

Declare camera, microphone, location, or motion access in `services.yaml`.
Declare optional UI extensions, such as maps or webview, in `ruflet.yaml`.

## CLI

```bash
ruflet run [scriptname|path] [--web|--desktop] [--port PORT]
ruflet debug [scriptname|path]
ruflet devices
ruflet emulators
ruflet doctor [--fix]
ruflet update [web|desktop|all] [--check] [--force]
ruflet build <apk|android|ios|aab|web|macos|windows|linux>
ruflet install [--device DEVICE_ID]
```

Run `ruflet install` without `--device` to choose from a numbered list of
connected devices. Pass `--device DEVICE_ID` to skip the prompt.

Add `--self` to a native build when the Ruby runtime and application should be
packaged inside the client. Without `--self`, the built client connects to a
separately running Ruflet backend.

## Rails

Use the `ruflet_rails` gem to mount Ruflet applications inside Rails, share
Rails models, and generate Ruflet components from standard Rails scaffolds.
It can also wrap ordinary Rails views in a native WebView shell with AppBars,
drawers, bottom navigation, sheets, menus, dialogs, and platform services
declared from ERB. See
[`packages/ruflet_rails/README.md`](packages/ruflet_rails/README.md).

## Packages

- `ruflet` provides the project generator and command-line tools.
- `ruflet_core` provides controls, page APIs, and the Ruby UI runtime.
- `ruflet_server` runs server-driven Ruflet applications.
- `ruflet_rails` integrates Ruflet with Rails.
- `ruby_runtime` embeds Ruby for self-contained native applications.
