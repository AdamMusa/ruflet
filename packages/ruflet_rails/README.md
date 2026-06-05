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
- add the Ruflet mount route to `config/routes.rb`
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

Plain Rails dev server commands do not launch the desktop app. Request a desktop
client explicitly with a flag:

```bash
bin/dev --desktop
bin/rails server --desktop
bin/rails s --desktop
```

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

## Ruflet resource scaffolds

Generate a Ruflet CRUD view for an existing Rails model:

```bash
bin/rails generate ruflet:scaffold Post
```

The scaffold creates generated app code the Rails developer can own and edit:

```ruby
# app/views/ruflet/posts_view.rb
require_relative "components/posts/post_component"

class PostView < RufletView
  include Ruflet::Rails::FormHelpers

  route "/posts"

  def render
    page.title = resource_title
    render_index
  end

  private

  def records
    # edit resource query logic here
  end

  def component
    @component ||= PostComponent.new(page, controller: self)
  end
end

# app/views/ruflet/components/posts/post_component.rb
class PostComponent < Ruflet::Rails::ResourceComponent
  def render
    # edit the scaffold layout here
  end
end
```

The generated view contains the resource logic: query, model helpers, field
introspection, save/delete, dialog close, and display formatting. The generated
component contains the UI: tables, lists, and dialogs. `ruflet_rails` only
provides the base classes and generic helpers. The generator does not dump field
declarations like `title:string` or literal metadata tables into the app.

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
match "/ws", to: Ruflet::Rails.app(Rails.root.join("app/views/ruflet/main.rb")), via: :all
```

The same mounted Ruby entrypoint drives mobile, web, and desktop clients.
