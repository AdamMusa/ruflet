# RubyNative Widget Guide

RubyNative DSL is widget-first, similar to Flet.

## Core concepts

- `page` defines page-level properties (`title`, `route`, `vertical_alignment`, ...)
- layout widgets compose children: `column`, `row`, `container`, `center`, `gesture_detector`
- content widgets: `text`, `text_field`, `button`, `icon_button`, `icon`
- IDs are auto-generated if you do not pass `id:`

## Basic counter example

```ruby
require "ruby_native"

page title: "Counter", vertical_alignment: "center" do
  center do
    row spacing: 8, alignment: "center" do
      icon_button icon: :remove
      text_field value: "0", width: 100, text_align: "right"
      icon_button icon: :add
    end
  end
end

app = RubyNative.app(host: "0.0.0.0", port: Integer(ENV.fetch("FLET_PORT", "8550")))
app.run
```

## Widget reference

Note: controls are explicit and class-backed in `ruby_native_ui/lib/ruby_native/ui/controls/*.rb`.
If a control is not implemented yet, RubyNative raises `Unsupported control type`.

## `page`

```ruby
page title: "Home", route: "/", vertical_alignment: "center" do
  # children
end
```

Common props:

- `title`
- `route`
- `vertical_alignment`
- `horizontal_alignment`

## `column`

Vertical layout.

```ruby
column spacing: 12, expand: true do
  text value: "A"
  text value: "B"
end
```

## `row`

Horizontal layout.

```ruby
row spacing: 8, alignment: "center" do
  text value: "Left"
  text value: "Right"
end
```

## `center`

Center wrapper.

```ruby
center do
  text value: "Centered"
end
```

Notes:

- behaves as centered container
- ignores `spacing` (by design)

## `text`

```ruby
text value: "Hello", size: 24
```

## `text_field`

```ruby
text_field value: "0", width: 100, text_align: "right"
```

Alias also available:

```ruby
textfield value: "0"
```

## `button`

```ruby
button text: "Click"
```

## `elevated_button`

Flet-compatible alias for elevated material button.

```ruby
elevated_button text: "7", on_click: ->(e) { puts e.name }
```

Alias:

```ruby
elevatedbutton text: "7"
```

## `icon_button`

```ruby
icon_button icon: :add
icon_button icon: :remove
```

Alias:

```ruby
iconbutton icon: :add
```

## `icon`

```ruby
icon name: "add"
```

## `gesture_detector`

Flet-style gesture wrapper for pointer/touch events.

```ruby
gesture_detector on_tap: lambda { |e| puts "tap: #{e.target}" } do
  container do
    text value: "Tap me"
  end
end
```

Supported gesture callbacks:

- `on_tap`
- `on_double_tap`
- `on_long_press`
- `on_hover`
- `on_pan_start`, `on_pan_update`, `on_pan_end`
- `on_scale_start`, `on_scale_update`, `on_scale_end`
- `on_vertical_drag_start`, `on_vertical_drag_update`, `on_vertical_drag_end`
- `on_horizontal_drag_start`, `on_horizontal_drag_update`, `on_horizontal_drag_end`

Alias also available:

```ruby
gesturedetector on_tap: lambda { |_e| } do
  text value: "Alias form"
end
```

## Generic `widget`

Use explicit widget type when needed:

```ruby
widget :text, value: "via generic widget"
```

## UI namespace helpers

You can call helpers through `RubyNative::UI`:

```ruby
RubyNative::UI.page title: "UI API" do
  RubyNative::UI.row alignment: "center" do
    RubyNative::UI.text value: "Hello"
  end
end
```

## Calculator pattern

```ruby
display = nil

page title: "Calculator" do
  column width: 360, spacing: 8 do
    display = text_field value: "0", read_only: true, text_align: "right"
    row spacing: 8 do
      elevated_button text: "1", on_click: ->(e) { e.page.update(display, value: "1") }
      elevated_button text: "2", on_click: ->(e) { e.page.update(display, value: "2") }
      elevated_button text: "+"
    end
  end
end

app.run
```
