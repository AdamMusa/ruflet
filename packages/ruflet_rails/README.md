# Ruflet Rails

`ruflet_rails` is the Rails-first integration package for Ruflet.

Internal Rails transport/protocol code is bundled inside this gem as `Ruflet::Rails::Protocol`.
No separate protocol gem is required.

## Usage

```ruby
# Gemfile
gem "ruflet_rails", ">= 0.0.2"
```

```ruby
# app/mobile/main.rb
require "ruflet"

class MyApp < Ruflet::App
  def view(page)
    page.title = "Hello"
    page.add(page.text(value: "Hello Ruflet"))
  end
end

MyApp.new.run
```

```ruby
# config/routes.rb
mount Ruflet::Rails.mobile(Rails.root.join("app/mobile/main.rb")), at: "/ws"
```

Connect mobile to Rails base URL, e.g. `http://10.0.2.2:3000`.
