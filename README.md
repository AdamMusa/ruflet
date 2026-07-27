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
- `ruflet.yaml` - runtime URL, assets, extensions, and build settings
- `services.yaml` - app identity and protected device capabilities
- `Gemfile` - Ruflet runtime dependencies

Set `app_name`, `package_name`, and `organization` under `app` in
`services.yaml`. Mobile builds derive `organization.package_name` and apply it
through `change_app_package_name`. Declare camera, microphone, location, or
motion access in the same file.

```yaml
app:
  app_name: My Ruflet App
  package_name: my_ruflet_app
  organization: com.example
  version: 1.0.0+1

services:
  - camera:
      description: Scan QR codes.
```

For this example, Android and iOS builds use
`com.example.my_ruflet_app` as the application identifier. Mobile builds stop
with a configuration error when any of these three identity fields is missing;
the Flutter template package name is never retained for an application build.
Declare optional UI extensions, such as maps or webview, in `ruflet.yaml`.

## CLI

```bash
ruflet run [scriptname|path] [--web|--desktop] [--port PORT] [--no-reload]
ruflet debug [scriptname|path]
ruflet devices
ruflet emulators
ruflet doctor [--fix]
ruflet update [web|desktop|all] [--check] [--force]
ruflet build <apk|android|ios|aab|web|macos|windows|linux>
ruflet install [--device DEVICE_ID]
```

Ruflet automatically refreshes its Flutter template and completed desktop/web
client prebuilds. Rolling clients are published to `prebuild-main`; the CLI
checks for a new revision every six hours and retains the last complete local
build if GitHub is unavailable. Run `ruflet update --force` to refresh
immediately or set `RUFLET_CLIENT_CHANNEL=stable` to use only versioned release
assets.

`ruflet run` hot reloads by default: it watches the project's `*.rb` files and
repaints every connected client over its live connection when a file changes
(the current route survives; open dialogs close; in-memory state resets; broken
edits keep the last good UI and print the error). In the terminal, press `r`
to force a reload or `R` for a full backend restart (clients reconnect
automatically — use it after Gemfile or ruflet.yaml changes). Pass
`--no-reload` to disable watching. Add `gem "bootsnap", require: false` to the
app's Gemfile to make full restarts a little faster (Ruflet caches compiled
bytecode under `~/.ruflet/bootsnap`).

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
