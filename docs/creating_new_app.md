# Creating a New Ruflet App

## 1) Install CLI (one-time)

```bash
gem install ruflet_cli
```

## 2) Create app

```bash
ruflet new my_app
cd my_app
```

CLI output after creation:

```text
Ruflet app created: my_app
```

## 3) Install dependencies

```bash
bundle install
```

## 4) Run app server

```bash
ruflet run main.rb
```

When running mobile target, CLI prints:
- mobile connect URL
- WebSocket URL
- QR code for scan-connect

## 5) Connect from mobile client

Install Ruflet mobile app from:
- [Ruflet Releases](https://github.com/AdamMusa/Ruflet/releases)

Then either:
- manually enter URL shown in terminal, or
- tap `Scan QR` and scan terminal QR

## 6) Target modes

```bash
ruflet run main.rb --mobile
ruflet run main.rb --web
ruflet run main.rb --desktop
```

`--mobile` is default.

## 7) Build binaries

```bash
ruflet build apk
ruflet build ios
ruflet build web
ruflet build macos
ruflet build windows
ruflet build linux
```

## Notes

- `ruflet new` generates app `Gemfile` using RubyGems dependencies (`ruflet` and `ruflet_server`).
- It does not include `ruflet_cli` in app dependencies.
- App code should use class-based style (`class App < Ruflet::App`), not DSL style.

## Default app structure (class-based, scaffold-style)

`main.rb`:

```ruby
require "ruflet"

class MyApp < Ruflet::App
  def view(page)
    app_name = "My App"
    page.title = app_name

    body = page.column(
      expand: true,
      alignment: Ruflet::MainAxisAlignment::CENTER,
      horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
      spacing: 8
    ) do
      text value: "Hello Ruflet", size: 28
      text value: "Edit main.rb and run again", size: 12
    end

    page.add(
      body,
      appbar: page.app_bar(title: page.text(value: app_name)),
      floating_action_button: page.fab("+", on_click: ->(_e) {})
    )
  end
end

MyApp.new.run
```
