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
mount Ruflet::Rails.native(app_file: Rails.root.join("app/views/ruflet/main.rb")), at: "/app"
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

## HTML as the UI DSL (no WebView)

Beyond the WebView shell, Ruflet can treat HTML itself as the UI language:
Rails views describe screens with markup, and `Ruflet::Rails.html_to_native`
compiles each page into **real native Ruflet controls** — no WebView anywhere.
This is HTML-over-the-wire for native UI: state lives in Rails, every
interaction is a request, and the response markup re-renders the screen.

```ruby
# app/views/ruflet/main.rb
Ruflet.run do |page|
  Ruflet::Rails.html_to_native(page, start_url: "#{Ruflet::Rails.backend_url}/native")
end
```

Screens are ordinary Rails views (ERB, controllers, sessions, and redirects
all work — requests carry the Rails session cookie and CSRF token, plus an
`X-Ruflet-Native: 1` header so a controller can render native markup and a
browser page from the same action):

```erb
<%# app/views/counters/show.html.erb %>
<appbar title="Counter"></appbar>

<column class="p-6 gap-4 items-center justify-center flex-1">
  <text class="text-5xl font-bold text-slate-900"><%= @count %></text>
  <row class="gap-3">
    <button variant="outlined" icon="remove" on-click="<%= counter_decrement_path %>">Down</button>
    <button variant="filled" icon="add" on-click="<%= counter_increment_path %>">Up</button>
  </row>
  <a href="<%= settings_path %>">Settings</a>
</column>
```

- **Layout** — `<column>`, `<row>`, `<stack>`, `<div>`/`<section>` (container),
  `<card>`, `<center>`, `<spacer>`, `<list>`, `<grid>`.
- **Content** — `<text>`, `<h1>`–`<h6>`, `<p>`, `<markdown>`, `<img>`, `<icon>`,
  `<hr>`, `<ul>`/`<li>`.
- **Styling** — a broad Tailwind-flavored `class` vocabulary that maps onto
  each control's real props (only the ones a control accepts are applied):
  - spacing & size: `p-4`, `px-6`, `m-2`, `-mt-2`, `gap-3`, `w-64`, `h-full`,
    `flex-1`, `aspect-video`, `aspect-[4/3]`
  - color: `bg-slate-100`, `text-emerald-600`, `bg-[#123456]`, theme tokens
    (`bg-primary`, `text-on-surface`), gradients
    (`bg-gradient-to-r from-blue-500 via-sky-400 to-cyan-300`)
  - typography: `text-xl`, `text-[42]`, `font-bold`, `font-mono`, `italic`,
    `text-center`, `tracking-wide`, `leading-relaxed`, `underline`,
    `line-through`, `uppercase`/`lowercase`/`capitalize`, `truncate`,
    `line-clamp-2`, `whitespace-nowrap`, `select-none`, `text-ellipsis`
  - shape & borders: `rounded-2xl`, `rounded-t-lg`, `rounded-br-sm`, `border`,
    `border-2`, `border-t`, `border-red-500`, `shadow-lg`, `opacity-75`, `blur-md`
  - transforms & position: `rotate-45`, `-rotate-12`, `scale-95`, `top-4`,
    `left-2`, `inset-0`/`inset-x-4` (Stack children)
  - transitions: `transition`, `duration-300`, `ease-in-out` (implicit animation)
  - layout & display: `items-center`, `justify-between`, `place-center`,
    `flex-wrap`, `gap-x-3`/`gap-y-2`, `size-12`, `w-screen`, `min-h-screen`,
    `scroll`, `overflow-hidden`, `object-cover` (image fit), `hidden`/`invisible`
  Anything not mapped is ignored; the full native prop is always available as
  an explicit attribute (`gradient='{…}'`, `blur="8"`, …).
- **Navigation** — `<a href>` pushes a native screen; `nav="replace|root|back"`
  change the mode. The native back button/gesture pops.
- **Actions** — `on-click="/counter/increment"` posts to Rails and re-renders
  the current screen in place with the response (`redirect_to` is followed).
  Prefix a verb for other methods: `on-click="delete:/items/3"`.
- **Forms** — `<form action method>` with named `<input>`, `<textarea>`,
  `<select>` fields tracks values natively and submits them like a normal
  Rails form, then renders the response.
- **App chrome** — `<appbar title="Inbox" leading-icon="menu">` with
  `<action icon="search" href="/search"/>` children becomes the native AppBar.
- **The whole widget catalog** — any other tag falls through to the ruflet_core
  control registry with its attributes as props:
  `<progress-bar value="0.4">`, `<switch label="Dark mode">`,
  `<chip label="New">`… kebab-case maps to the control name.

**First-class components** — these have dedicated tags/helpers that map to the
right native shape (some Ruflet "components" are *props* on another control,
not controls of their own — the DSL handles that for you):

| Tag | Helper | Notes |
| --- | --- | --- |
| `<badge label="3">…</badge>` | `badge` | wraps its child; badge is a prop on it |
| `<tooltip message="…">…</tooltip>` | `tooltip` | prop on its child |
| `<chip label="Ruby" icon="star">` | `chip` | text → `label`; `on-click`/`href` supported |
| `<avatar src>` / `<avatar>AM</avatar>` | `avatar` | image or initials |
| `<list-tile title subtitle leading href>` | `list_tile` | taps navigate/act natively |
| `<expansion-tile title>…</expansion-tile>` | `expansion_tile` | collapsible section |
| `<switch>` `<checkbox>` `<slider>` `<radio>` | same | standalone; `name` makes them form fields |
| `<radio-group name value>…radios…</radio-group>` | `radio_group` | |
| `<segmented-button name value>…<segment>…</segmented-button>` | `segmented_button` | |
| `<tabs><tab label icon>…</tab></tabs>` | `tabs` / `tab` | native TabBar + panes |
| `<table><thead><tr><th>…` | — | plain HTML tables → native `DataTable` |
| `<fab icon href>` | `fab` | mounts as the screen's FloatingActionButton |
| `<bottom-nav><nav-item icon label href selected>…` | `bottom_nav` / `nav_item` | screen's NavigationBar; a tab resets to that URL as root |

**Every Ruflet control is reachable.** Any tag without a dedicated builder
maps straight onto the ruflet_core control registry — the entire catalog
(charts, canvas, cupertino_*, maps, sensors, list/menu/expansion controls, …)
works from markup. The passthrough is schema-aware: a control's text and child
elements are routed into whichever prop it actually accepts (`content`,
`controls`, `label`, `title`), so `<filled-button>Save</filled-button>`,
`<banner><text>…</text></banner>`, and `<responsive-row>…</responsive-row>`
all build correctly. Use the raw tag (kebab-case → control name) or the
`widget` helper:

```erb
<%= widget "bar-chart", expand: true do %>
  <%= widget "bar-chart-group", x: 0 do %>
    <%= widget "bar-chart-rod", from_y: 0, to_y: 10 %>
  <% end %>
<% end %>

<cupertino-activity-indicator animating="true"></cupertino-activity-indicator>
```

**Services and extensions.** Non-visual platform services (`<geolocator>`,
`<battery>`, `<clipboard>`, `<flashlight>`, `<permission-handler>`,
`<secure-storage>`, `<shared-preferences>`, `<file-picker>`, `<wakelock>`,
`<share>`, `<url-launcher>`, the sensors, …) are non-visual: declaring one
mounts it on the screen's service registry rather than in the layout. Extension
controls that *do* render (`<camera>`, `<audio>`, `<video>`, `<lottie>`,
`<rive>`, `<map>`, `<code-editor>`, `<web-view>`, `<spinkit>`,
`<color-picker>`, the charts) render inline like any other control. Each has a
matching helper:

```erb
<%= geolocator %>
<%= camera id: "camera-preview", preview_enabled: true %>
<%= video src: "clip.mp4" %>
<%= lottie src: "loader.json" %>
<%= map do %><%= widget "tile-layer", url_template: "…" %><% end %>
```

Buttons can invoke native services without a request back to Rails. Common
operations have short names, and the open-ended `method`/`args` form exposes
new service methods without waiting for another `ruflet_rails` release:

```erb
<%= button "Copy", service: "copy", text: "Hello from Rails" %>
<%= button "Locate", service: "location" %>
<%= button "Allow camera",
           service: "permission-handler",
           method: "request",
           args: { permission: "camera" } %>
```

An inline extension can also be controlled by its native ID:

```erb
<%= audio id: "player", src: "https://example.com/song.mp3" %>
<%= button "Play", service: "control", target: "player", method: "play" %>
<%= button "Seek", service: "control", target: "player",
                   method: "seek", position: 2_000 %>
```

Service results and errors are reported in a native dialog by default. For a
stream such as an accelerometer, pass `result_target: "status-control-id"` to
update an inline Text control instead.

```erb
<%# a form, natively rendered %>
<form action="<%= session_path %>" method="post">
  <column class="p-6 gap-4">
    <h2>Sign in</h2>
    <input type="email" name="email" label="Email" placeholder="you@example.com">
    <input type="password" name="password" label="Password">
    <input type="checkbox" name="remember" label="Remember me" checked>
    <input type="submit" value="Sign in">
  </column>
</form>
```

### Ruby helper DSL

The same markup can be authored with Ruby helpers (auto-included into
ActionView), and both styles mix freely in one template. Attribute keys are
snake_case and become kebab-case attributes (`on_click:` → `on-click`);
Hash/Array values serialize as JSON:

```erb
<%= appbar "Counter" %>

<%= column class: "p-6 gap-6 items-center justify-center flex-1" do %>
  <%= text @count, class: "text-[96] font-bold" %>
  <%= row class: "gap-3" do %>
    <%= button "Down", variant: "outlined", icon: "remove",
               on_click: counter_decrement_path %>
    <%= button "Up", variant: "filled", icon: "add",
               on_click: counter_increment_path %>
  <% end %>
  <%= link "Settings", settings_path %>
<% end %>
```

Available helpers: layout (`column`, `row`, `stack`, `card`, `center`,
`list`, `grid`, `spacer`, `divider`), content (`text`, `h1`–`h6`/`heading`,
`markdown`, `image`, `icon`), interaction (`button`, `link`), chrome
(`appbar`, `appbar_action`), forms (`form`, `input`, `textarea`, `dropdown`,
`submit`), and `widget("progress-bar", value: 0.4)` for anything else in the
control registry.

Pick the mode per app: `html_to_native` when HTML should *become* native controls,
`native_shell` when you want the real web page in a WebView with native chrome.

## Native WebView shell

Beyond the server-driven UI, Ruflet can wrap an existing Rails HTML app in a
managed native WebView. This is an opt-in shell: calling
`Ruflet::Rails.native_shell` wraps web pages in a native Ruflet shell whose body is
a WebView. Plain `Ruflet.run { |page| ... }` remains a normal Ruflet app with no
WebView wrapper or HTML adapter.

Native behavior is explicit from Rails views: ordinary links and Turbo visits
stay inside the WebView, while links annotated with `data-ruflet-*` can push
native screens, replace/root the stack, open a sheet, show a dialog, toast, or
promote page chrome.

```ruby
# app/views/ruflet/main.rb
Ruflet.run do |page|
  Ruflet::Rails.native_shell(
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

For a Fizzy-style web app, keep `Ruflet::Rails.native_shell` simple and opt in from
the views that need native treatment:

```ruby
# app/views/ruflet/main.rb
Ruflet.run do |page|
  Ruflet::Rails.native_shell(page, start_url: "#{Ruflet::Rails.backend_url}/")
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
