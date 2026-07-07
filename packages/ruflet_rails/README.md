# Ruflet Rails

`ruflet_rails` is the Rails-first integration package for Ruflet.

It mounts Ruby-driven Ruflet interfaces in a Rails application, makes Rails
views able to opt into native WebView chrome, and connects web, mobile, and
desktop clients to the same application entrypoint.

## Add The Gem

```ruby
# Gemfile
gem "ruflet_rails"
```

## Install Into Rails

```bash
bin/rails generate ruflet:install
bin/rails generate ruflet:install --web
bin/rails generate ruflet:install --desktop
bin/rails generate ruflet:install --web --desktop
```

This generator will:
- create `app/views/ruflet/main.rb`
- create `config/initializers/ruflet.rb`
- add the Ruflet WebSocket route to `config/routes.rb`
- add a `/ruflet` web mount when `--web` is used
- download prebuilt clients from GitHub releases when `--web`, `--desktop`, or
  `--client=web|desktop|all` is used

Generated `config/initializers/ruflet.rb`:

```ruby
Ruflet::Rails.configure do |config|
  config.app_name = "My App"
  config.backend_url = ENV.fetch("RUFLET_BACKEND_URL", "http://localhost:3000")

  config.services = []

  config.splash_screen = Rails.root.join("app/assets/images/splash.png")
  config.icon_launcher = Rails.root.join("app/assets/images/icon.png")
end
```

At build time `ruflet_rails` serializes this Rails config into the Ruflet CLI
config shape, so the initializer remains the source of truth for app name,
backend URL, services, assets, and build colors.

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
Rails backend configured in `config/initializers/ruflet.rb`; it does not package a self-contained
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

## Native WebView shell

Beyond the server-driven UI, Ruflet can wrap an existing Rails HTML app in a
managed native WebView. This is an opt-in shell: calling
`Ruflet::Rails.native_app` wraps web pages in a native Ruflet shell whose body is
a WebView. Plain `Ruflet.run { |page| ... }` remains a normal Ruflet app with no
WebView wrapper or HTML adapter.

Native behavior is explicit from Rails views: ordinary links and Turbo visits
stay inside the WebView, while links annotated with `data-ruflet-*` can push
native screens, replace/root the stack, open a sheet, show a dialog, toast, or
promote page chrome.

```ruby
# app/views/ruflet/main.rb
Ruflet.run do |page|
  Ruflet::Rails.native_app(
    page,
    start_url: "https://myapp.com",
    title: "My App",                       # opt into a native AppBar (tracks <title>)
    loading: :shimmer                      # default; can be "Loading..." or false
  )
end
```

### Crossing web and native from HTML

A tiny HTML adapter reads `data-ruflet-*` attributes from the rendered page and
sends those payloads back to Ruby. Ruby then builds the native AppBar, drawer,
tabs, dialogs, sheets, services, and navigation with normal Ruflet controls. The
page stays a normal page in a plain browser; the attributes only activate inside
the native shell. Keep using normal Rails helpers like `link_to`; add Ruflet data
attributes only where the native app should augment the web behavior.

**Navigation** — `action` is `push` (default), `root` (reset to a root screen,
tab-style), `replace`, `sheet`, or `back`:

```erb
<%= link_to "Messages", messages_path,
      data: { ruflet_screen: { action: "push", title: "Messages" }.to_json } %>

<%= link_to "Sign in", new_session_path,
      data: { ruflet_screen: { action: "push", title: "Sign in",
        leading: { icon: "close", action: "back" } }.to_json } %>

<%= link_to "Sign in", new_session_path,
      data: { ruflet_screen: { action: "sheet" }.to_json } %>

<a href="/dashboard" data-ruflet-screen='{"action":"root","title":"Dashboard"}'>Dashboard</a>
```

**Promote HTML chrome to native** — hide HTML header/nav elements and render
native AppBar, NavigationBar, NavigationDrawer, or desktop NavigationRail:

```erb
<%= tag.div hidden: true,
      data: { ruflet_appbar: { title: "Sign in",
        leading: { icon: "close", action: "back" } }.to_json } %>

<%= ruflet_appbar "Inbox", leading: { icon: "menu", action: "drawer" } do %>
  <%= ruflet_appbar_action "search", search_path %>
<% end %>

<%= ruflet_drawer do %>
  <%= ruflet_drawer_item "Home", root_path, icon: "home", selected: true %>
  <%= ruflet_drawer_item "Settings", settings_path, icon: "settings", nav: :push %>
<% end %>

<%= ruflet_bottom_nav do %>
  <%= ruflet_nav_item "Home", root_path, icon: "house", selected: true %>
  <%= ruflet_nav_item "Profile", profile_path, icon: "person" %>
<% end %>

<%= ruflet_navigation_rail extended: true, breakpoint: 720 do %>
  <%= ruflet_rail_item "Home", root_path, icon: "home", selected: true %>
  <%= ruflet_rail_item "Inbox", inbox_path, icon: "mail" %>
  <%= ruflet_rail_item "Settings", settings_path, icon: "settings", nav: :push %>
<% end %>
```

**Native dialogs and toasts** — from annotated Rails links and buttons.
Dialogs, bottom sheets, and snackbars are adaptive by default, so the native shell
can use platform-appropriate presentation instead of forcing the same Material
look everywhere:

```erb
<%= link_to "Delete", item_path(item),
      data: { ruflet_action: { component: "dialog", title: "Delete?",
        content: "This cannot be undone.", confirm: "Delete", action: "replace" }.to_json } %>

<%= button_tag "Copy link",
      data: { ruflet_action: { component: "toast", message: "Copied to clipboard" }.to_json } %>
```

**Native menus and bottom sheets** — menus are regular Ruflet bottom sheets
driven by Rails payload data. Item taps close the native sheet first, wait for
the native dismiss event, then run the item callback or navigation. This keeps
the overlay lifecycle stable on mobile and desktop.

```erb
<%= ruflet_appbar "T4U",
      actions: [
        {
          icon: "language",
          action: "menu",
          title: "Language",
          items: [
            { label: "FR", icon: "check", url: url_for(locale: :fr), action: "root", selected: I18n.locale == :fr },
            { label: "EN", icon: "translate", url: url_for(locale: :en), action: "root" },
            { label: "AR", icon: "translate", url: url_for(locale: :ar), action: "root" }
          ]
        }
      ] %>
```

Items close the sheet by default. Pass `close: false` only for an item that
should run without dismissing the sheet:

```erb
<%= ruflet_appbar "Filters",
      actions: [
        {
          icon: "tune",
          action: "menu",
          title: "Filters",
          items: [
            { label: "Toggle remote only", icon: "check", close: false }
          ]
        }
      ] %>
```

Use `action: "sheet"` to present a Rails URL inside a native bottom sheet whose
body is still a WebView:

```erb
<%= link_to "Choose language", languages_path,
      data: { ruflet_action: { component: "sheet", url: languages_path }.to_json } %>
```

Inside a WebView sheet, plain Rails links are promoted to native actions so the
sheet closes before navigation:

```erb
<!-- app/views/languages/index.html.erb, rendered inside the sheet -->
<%= link_to "Français", url_for(locale: :fr) %>
<%= link_to "English", url_for(locale: :en) %>
<%= link_to "العربية", url_for(locale: :ar) %>
```

Add `data-ruflet-close="false"` when a sheet link should not dismiss:

```erb
<%= link_to "Preview", preview_path, data: { ruflet_close: "false" } %>
```

**Native services** — ERB can trigger safe platform services through the same
`data-ruflet-action` channel:

```erb
<%= ruflet_share_link "Share", "#",
      text: "Look at this", title: "My App" %>

<%= ruflet_copy_button "Copy invite", text: invite_url(@invite) %>

<%= ruflet_launch_link "Open docs", "https://flutteronrails.com" %>

<%= ruflet_haptic_button "Tap", style: "light" %>
```

For a Fizzy-style web app, keep `Ruflet::Rails.native_app` simple and opt in from
the views that need native treatment:

```ruby
# app/views/ruflet/main.rb
Ruflet.run do |page|
  Ruflet::Rails.native_app(page, start_url: "#{Ruflet::Rails.backend_url}/")
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
