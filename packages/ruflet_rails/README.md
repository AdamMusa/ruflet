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
bin/rails generate ruflet:install --client=web
bin/rails generate ruflet:install --client=desktop
```

This generator will:
- create `app/views/ruflet/main.rb`
- create `app/views/ruflet/components/application_component.rb`
- create `ruflet.yaml`
- add the Ruflet mount route to `config/routes.rb`
- download prebuilt clients from GitHub releases when `--client=web|desktop|all` is used

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

Rails web builds are published to `public/ruflet` and served by Rails at `/ruflet/`.

`desktop` is also accepted as a host-platform alias:

```bash
bundle exec rake ruflet:build[desktop]
```

Rails desktop builds are server-driven. The built desktop app connects back to the
Rails backend configured in `ruflet.yaml`; it does not package a self-contained
Ruby runtime.

## Update prebuilt clients

Uses the same GitHub release assets as `ruflet update`:

```bash
bundle exec rake ruflet:update[web]
bundle exec rake ruflet:update[desktop]
bundle exec rake ruflet:update[all]
```

For web, the downloaded static client is published to `public/ruflet` and served
by Rails at `/ruflet/`. The Rails app does not vendor Flutter source code.

## Install mobile build

Uses the same install pipeline as `ruflet install`:

```bash
bundle exec rake ruflet:install
bundle exec rake ruflet:install[DEVICE_ID]
```

## Ruflet model scaffolds

Generate a Ruflet UI view scaffold for a Rails model:

```bash
bin/rails generate ruflet:scaffold Post title:string body:text
```

This creates:

```text
app/views/ruflet/posts/posts_view.rb
```

Or generate it alongside a normal Rails scaffold:

```bash
bin/rails generate scaffold Post title:string body:text --ruflet
```

The `--ruflet` option delegates to `ruflet:scaffold`, so Rails scaffold and
Ruflet scaffold generate the same Ruflet view file.

The generated file is grouped by model under Rails views, for example
`app/views/ruflet/posts/posts_view.rb`.

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

The generated form lives at `app/views/ruflet/components/posts/post_form.rb`
and subclasses `ApplicationComponent`, so it is auto-loaded before views.

## Shared Ruflet components

Put shared Ruflet UI components under `app/views/ruflet/components`. Component
files are loaded before `*_view.rb` files, so views can call them directly:

```ruby
# app/views/ruflet/components/page_title_component.rb
class PageTitleComponent < ApplicationComponent
  def render(value)
    text(value, size: desktop? || web? ? 28 : 24, weight: "bold")
  end
end
```

```ruby
# app/views/ruflet/posts/posts_view.rb
class PostsView < RufletView
  def render
    page.add(PageTitleComponent.render(page, "Posts"))
  end
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
mount Ruflet::Rails.app(Rails.root.join("app/views/ruflet/main.rb")), at: "/ws"
```

The same mounted Ruby entrypoint drives mobile, web, and desktop clients.
