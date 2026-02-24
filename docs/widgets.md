# RubyNative Widgets Guide

This guide covers the basics of building UI in RubyNative: app structure, layout widgets, content widgets, events, and updating controls.

## 1) App structure

RubyNative apps usually follow one of these styles:

- DSL style (`page do ... end`)
- Class style (`class MyApp < RubyNative::App`)

### DSL style

```ruby
require "ruby_native"

page title: "Hello", vertical_alignment: "center", horizontal_alignment: "center" do
  text value: "Hello RubyNative"
end

RubyNative.app.run
```

### Class style

```ruby
require "ruby_native"

class MyApp < RubyNative::App
  def view(page)
    page.title = "Hello"
    page.add(page.text(value: "Hello RubyNative"))
  end
end

MyApp.new.run
```

## 2) Page basics

Common page properties:

- `title`
- `route`
- `bgcolor`
- `vertical_alignment`
- `horizontal_alignment`

Example:

```ruby
page title: "Home", route: "/", bgcolor: "#F5F5F5", vertical_alignment: "start" do
  text value: "Dashboard"
end
```

Page-level centering (Flet Python style):

```ruby
class CenteredApp < RubyNative::App
  def view(page)
    page.title = "Centered"
    page.vertical_alignment = RubyNative::MainAxisAlignment::CENTER
    page.horizontal_alignment = RubyNative::CrossAxisAlignment::CENTER
    page.add(page.text(value: "Hello World!", size: 32))
  end
end

CenteredApp.new.run
```

## 3) Layout widgets

### `column`

Vertical layout.

```ruby
column spacing: 12 do
  text value: "Line 1"
  text value: "Line 2"
end
```

Useful props:

- `spacing`
- `alignment`
- `horizontal_alignment`
- `expand`

### `row`

Horizontal layout.

```ruby
row spacing: 8, alignment: "center" do
  button text: "Cancel"
  button text: "Save"
end
```

Useful props:

- `spacing`
- `alignment`
- `vertical_alignment`
- `expand`

### `container`

Box wrapper for size, padding, color, border, and content.

```ruby
container width: 240, padding: 12, bgcolor: "#FFFFFF", border_radius: 10 do
  text value: "Card content"
end
```

### `center`

Centers one child.

```ruby
center do
  text value: "Centered"
end
```

Framework note:
- `center` is implemented as an expanding `container` with `alignment: "center"` (Flet-style behavior).
- It centers both horizontally and vertically in available space.

Flet Python equivalent:

```python
import flet as ft

def main(page: ft.Page):
    page.add(
        ft.Container(
            expand=True,
            alignment=ft.alignment.center,
            content=ft.Text("Centered")
        )
    )
```

RubyNative equivalent:

```ruby
page.add(
  center do
    text value: "Centered"
  end
)
```

For axis-based centering in layouts:

```ruby
column expand: true, alignment: "center", horizontal_alignment: "center" do
  text value: "Centered in column"
end

row expand: true, alignment: "center", vertical_alignment: "center" do
  text value: "Centered in row"
end
```

### `stack`

Absolute/overlay layout.

```ruby
stack do
  container left: 10, top: 10, width: 120, height: 80, bgcolor: "#ddd"
  text left: 20, top: 20, value: "On top"
end
```

## 4) Content widgets

### `text`

```ruby
text value: "Title", size: 24, weight: "bold"
```

### `text_field` / `textfield`

```ruby
text_field label: "Name", value: "", width: 220
```

### `button` / `elevated_button`

```ruby
button text: "Submit"
elevated_button text: "Primary"
```

### `icon` and `icon_button`

```ruby
icon icon: RubyNative::MaterialIcons::HOME
icon_button icon: RubyNative::MaterialIcons::ADD
```

### `image`

```ruby
image src: "https://example.com/pic.png", width: 120, height: 120, fit: "contain"
```

## 5) Colors

You can use hex strings or `RubyNative::Colors`.

```ruby
text value: "Hello", color: RubyNative::Colors.BLUE_700
container bgcolor: RubyNative::Colors.SURFACE_CONTAINER_LOW
```

Helpers:

```ruby
RubyNative::Colors.random
RubyNative::Colors.with_opacity(0.5, RubyNative::Colors.BLUE)
```

## 6) Events and gestures

### Button click

```ruby
elevated_button text: "Tap", on_click: ->(e) { puts e.name }
```

### Gesture detector

```ruby
gesture_detector on_tap: ->(_e) { puts "tap" } do
  container padding: 8 do
    text value: "Tap me"
  end
end
```

Common callbacks:

- `on_tap`
- `on_double_tap`
- `on_long_press`
- `on_pan_start`, `on_pan_update`, `on_pan_end`
- `on_scale_start`, `on_scale_update`, `on_scale_end`

## 7) Updating controls (state)

Pattern:

1. Keep a reference to a control.
2. Update it via `page.update(...)` from events.

```ruby
count = 0
counter = nil

page title: "Counter" do
  counter = text value: count.to_s, size: 40

  elevated_button text: "+", on_click: ->(e) {
    count += 1
    e.page.update(counter, value: count.to_s)
  }
end
```

## 8) App bar and floating action button

```ruby
page.add(
  page.column do
    page.text(value: "Body")
  end,
  appbar: page.app_bar(
    bgcolor: "#2196F3",
    color: "#FFFFFF",
    title: page.text(value: "My App")
  ),
  floating_action_button: page.fab("+", on_click: ->(_e) { puts "fab" })
)
```

## 9) Complete basic example

```ruby
require "ruby_native"

class CounterApp < RubyNative::App
  def initialize
    super
    @count = 0
  end

  def view(page)
    page.title = "Counter"
    page.vertical_alignment = RubyNative::MainAxisAlignment::CENTER
    page.horizontal_alignment = RubyNative::CrossAxisAlignment::CENTER

    counter = page.text(value: @count.to_s, size: 48)

    body = page.column(horizontal_alignment: "center", spacing: 8) do
      text "You clicked:"
      counter
    end

    page.add(
      body,
      appbar: page.app_bar(title: page.text(value: "Counter")),
      floating_action_button: page.fab("+", on_click: ->(e) {
        @count += 1
        e.page.update(counter, value: @count.to_s)
      })
    )
  end
end

CounterApp.new.run
```

## 10) Notes

- Control names are aligned with Flet-style naming.
- Some controls may be unavailable; unsupported controls raise an error.
- Use `ruby_native run main.rb` to run your app.
