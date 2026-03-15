# Creating a New Ruflet App

## 1) Install Ruflet (one-time)

```bash
gem install ruflet
```

## 2) Create app

```bash
ruflet new my_app
cd my_app
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
ruflet run main.rb --web
ruflet run main.rb --desktop
```

Mobile is the default target, so `ruflet run main.rb` is enough.

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

- `ruflet new` generates app `Gemfile` with `gem "ruflet_core"` and `gem "ruflet_server"`.
- App code can use `Ruflet.run do |page| ... end` or a class-based app.

## Default app structure

`main.rb`:

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
