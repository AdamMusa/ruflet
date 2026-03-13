# Ruflet Rails

`ruflet_rails` is the Rails-first integration package for Ruflet.

Internal Rails transport/protocol code is bundled inside this gem as `Ruflet::Rails::Protocol`.
No separate protocol gem is required.

## Usage

```ruby
# Gemfile
gem "ruflet_rails", ">= 0.0.5"
```

## Install into Rails

```bash
bin/rails generate ruflet:install
```

This generator will:
- create `app/mobile/main.rb`
- create `ruflet.yaml`
- add the Ruflet mount route to `config/routes.rb`
- copy/configure `ruflet_client` when the template is available locally

Generated `ruflet.yaml`:

```yaml
app:
  name: My App
  ruflet_client_url: ""

services: []

assets:
  splash_screen: assets/splash.png
  icon_launcher: assets/icon.png
```

For Rails apps, those asset paths are resolved from `app/assets/` during build.

## Build client from Rails

Uses the same build pipeline as `ruflet build`:

```bash
bundle exec rake ruflet:build[web]
bundle exec rake ruflet:build[macos]
bundle exec rake ruflet:build[windows]
bundle exec rake ruflet:build[linux]
bundle exec rake ruflet:build[apk]
bundle exec rake ruflet:build[android]
bundle exec rake ruflet:build[ios]
bundle exec rake ruflet:build[aab]
```

## Manual usage

```ruby
# app/mobile/main.rb
require "ruflet"

Ruflet.run do |page|
  page.title = "Hello"
  page.add(text("Hello Ruflet"))
end
```

Connect mobile to Rails base URL, e.g. `http://10.0.2.2:3000`.
