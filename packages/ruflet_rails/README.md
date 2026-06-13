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
bin/rails generate ruflet:install --web
bin/rails generate ruflet:install --desktop
bin/rails generate ruflet:install --web --desktop
```

This generator will:
- create `app/views/ruflet/main.rb`
- create `ruflet.yaml`
- add the Ruflet WebSocket route to `config/routes.rb`
- add a `/ruflet` web mount when `--web` is used
- download prebuilt clients from GitHub releases when `--web`, `--desktop`, or
  `--client=web|desktop|all` is used

Generated `ruflet.yaml`:

```yaml
app:
  name: My App
  backend_url: http://localhost:3000

services: []

assets:
  splash_screen: assets/splash.png
  icon_launcher: assets/icon.png
```

For Rails apps, those asset paths are resolved from `app/assets/` during build.

## Web client

Rails installs the prebuilt web client into `frontend/`; it does not need
Flutter source or a Flutter web build:

```bash
bundle exec rake ruflet:web
```

Mount the installed client and a developer-owned Ruflet entrypoint:

```ruby
mount Ruflet::Rails.web_app(app_file: Rails.root.join("app/views/ruflet/main.rb")), at: "/app"
```

The install generator adds the same mount at `/ruflet` when `--web` is used.
The mount serves the static client and its WebSocket endpoint together. The
same `main.rb` also drives native clients through the generated `/ws` route.

## Build native clients from Rails

Uses the same native build pipeline as `ruflet build`:

```bash
bundle exec rake ruflet:build[macos]
bundle exec rake ruflet:build[windows]
bundle exec rake ruflet:build[linux]
bundle exec rake ruflet:build[apk]
bundle exec rake ruflet:build[android]
bundle exec rake ruflet:build[ios]
bundle exec rake ruflet:build[aab]
```

`desktop` is also accepted as a host-platform alias:

```bash
bundle exec rake ruflet:build[desktop]
```

Rails desktop builds are server-driven. The built desktop app connects back to the
Rails backend configured in `ruflet.yaml`; it does not package a self-contained
Ruby runtime.

Plain Rails dev server commands do not launch the desktop app. Request a desktop
client explicitly with a flag:

```bash
bin/dev --desktop
bin/rails server --desktop
bin/rails s --desktop
```

## Update prebuilt clients

Reinstall web or update native desktop clients:

```bash
bundle exec rake ruflet:web
bundle exec rake ruflet:update[desktop]
```

The Rails app does not vendor Flutter source code.

## Install mobile build

Uses the same install pipeline as `ruflet install`:

```bash
bundle exec rake ruflet:install
bundle exec rake ruflet:install[DEVICE_ID]
```

## Ruflet resource scaffolds

Generate a mountable Ruflet CRUD component for an existing Rails model:

```bash
bin/rails generate ruflet:scaffold Post
```

The scaffold creates generated app code the Rails developer can own and edit:

```ruby
# app/views/ruflet/components/posts/post_component.rb
class PostComponent < Ruflet::Rails::ResourceComponent
  def render
    # edit the scaffold layout here
  end
end
```

Mount it explicitly in `config/routes.rb`:

```ruby
mount Ruflet::Rails.web_app(view: "PostComponent"), at: "/posts"
```

The generated component contains the developer-owned UI and persistence calls.
`ruflet_rails` provides the reusable model, navigation, dialog, and formatting
helpers. Component files under `app/views/ruflet/components` are loaded by the
Railtie so both web mounts and `main.rb` can reference them.

## Ruflet model forms

Generate only a reusable Ruflet form for an existing Rails model:

```bash
bin/rails generate ruflet:form Post
```

When no fields are passed, the generator reads the model columns and skips `id`,
`created_at`, and `updated_at`. You can also pass fields explicitly:

```bash
bin/rails generate ruflet:form Post title:string body:text published:boolean category:references
```

Foreign keys and references, such as `category:references` or `user_id`, render
as Ruflet dropdowns populated from the associated Rails model.

The generated form lives at `app/views/ruflet/components/posts/post_form.rb`.
The form generator creates `app/views/ruflet/components/application_component.rb`
when that base component does not already exist.

## Shared Ruflet components

Put shared Ruflet UI components under `app/views/ruflet/components`. Those files
are reloaded with Rails application code:

```ruby
# app/views/ruflet/components/page_title_component.rb
class PageTitleComponent < ApplicationComponent
  def render(value)
    text(value, size: desktop? || web? ? 28 : 24, weight: "bold")
  end
end
```

```ruby
# app/views/ruflet/main.rb
Ruflet.run do |page|
  page.add(PageTitleComponent.render(page, "Posts"))
end
```

## Manual usage

```ruby
# app/views/ruflet/main.rb
require "ruflet"

Ruflet.run do |page|
  page.title = "Hello"
  page.add(text("Hello Ruflet"))
end
```

Mount it in Rails:

```ruby
match "/ws", to: Ruflet::Rails.app(Rails.root.join("app/views/ruflet/main.rb")), via: :all
```

The same mounted Ruby entrypoint drives mobile, web, and desktop clients.
