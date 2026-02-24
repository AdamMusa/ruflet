# RubyNative Widgets Guide (Class-Based)

This guide uses class-based apps only.

## 1) App structure

```ruby
require "ruby_native"

class MyApp < RubyNative::App
  def view(page)
    app_name = "Hello"
    page.title = app_name

    body = page.column(
      expand: true,
      alignment: RubyNative::MainAxisAlignment::CENTER,
      horizontal_alignment: RubyNative::CrossAxisAlignment::CENTER,
      spacing: 8
    ) do
      text value: "Hello RubyNative", size: 28
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

This is the recommended scaffold-style pattern:
- `appbar:` for top bar
- `body` control(s) in `page.add(...)`
- `floating_action_button:` for primary action

## 2) Page basics

Common page properties:
- `title`
- `route`
- `bgcolor`
- `vertical_alignment`
- `horizontal_alignment`

Flet-style page centering:

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

```ruby
class LayoutApp < RubyNative::App
  def view(page)
    page.add(
      page.column(spacing: 12) do
        text value: "Line 1"
        text value: "Line 2"
      end
    )
  end
end
```

### `row`

```ruby
class RowApp < RubyNative::App
  def view(page)
    page.add(
      page.row(spacing: 8, alignment: "center") do
        button text: "Cancel"
        button text: "Save"
      end
    )
  end
end
```

### `container`

```ruby
class ContainerApp < RubyNative::App
  def view(page)
    page.add(
      page.container(width: 240, padding: 12, bgcolor: "#FFFFFF", border_radius: 10) do
        text value: "Card content"
      end
    )
  end
end
```

### `center`

```ruby
class CenterWidgetApp < RubyNative::App
  def view(page)
    page.add(
      page.center do
        text value: "Centered"
      end
    )
  end
end
```

## 4) Content widgets

```ruby
class ContentApp < RubyNative::App
  def view(page)
    page.add(
      page.column(spacing: 10) do
        text value: "Title", size: 24, weight: "bold"
        text_field label: "Name", width: 220
        elevated_button text: "Primary"
      end
    )
  end
end
```

## 5) Events and updates

```ruby
class CounterApp < RubyNative::App
  def initialize
    super
    @count = 0
  end

  def view(page)
    counter = page.text(value: @count.to_s, size: 48)

    page.add(
      page.column(horizontal_alignment: "center", spacing: 8) do
        text value: "You clicked:"
        counter
      end,
      floating_action_button: page.fab("+", on_click: ->(e) {
        @count += 1
        e.page.update(counter, value: @count.to_s)
      })
    )
  end
end

CounterApp.new.run
```

## 6) App bar and FAB

```ruby
class AppBarApp < RubyNative::App
  def view(page)
    page.add(
      page.text(value: "Body"),
      appbar: page.app_bar(
        bgcolor: "#2196F3",
        color: "#FFFFFF",
        title: page.text(value: "My App")
      ),
      floating_action_button: page.fab("+", on_click: ->(_e) { puts "fab" })
    )
  end
end
```

## Notes

- Use class-based apps for new projects and examples.
- Use `ruby_native run main.rb` to run your app.
