# Ruflet Rails

`ruflet_rails` is the Rails-first integration package for Ruflet.

Internal Rails transport/protocol code is bundled inside this gem as `Ruflet::Rails::Protocol`.
No separate protocol gem is required.

## Usage

```ruby
# Gemfile
gem "ruflet_rails", ">= 0.0.4"
```

```ruby
# app/mobile/main.rb
require "ruflet"

class MainApp < Ruflet::App
  def initialize
    super
    @count = 0
  end

  def view(page)
    page.title = "Counter Demo"
    count_text = page.text(value: @count.to_s, size: 40)
    
    page.add(
      page.container(
        expand: true,
        padding: 24,
        content: page.column(
          expand: true,
          alignment: Ruflet::MainAxisAlignment::CENTER,
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          spacing: 12,
          controls: [
            page.text(value: "You have pushed the button this many times:"),
            count_text
          ]
        )
      ),
      appbar: page.app_bar(
        title: page.text(value: "Counter Demo")
      ),
      floating_action_button: page.fab(
        page.icon(icon: Ruflet::MaterialIcons::ADD),
        on_click: ->(_e) {
          @count += 1
          page.update(count_text, value: @count.to_s)
        }
      )
    )
  end
end

MainApp.new.run
```

```ruby
# config/routes.rb
mount Ruflet::Rails.mobile(Rails.root.join("app/mobile/main.rb")), at: "/ws"
```

Connect mobile to Rails base URL, e.g. `http://10.0.2.2:3000`.
