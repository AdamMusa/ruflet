# Ruflet Rails

`ruflet_rails` is the Rails-first integration package for Ruflet.

It follows Rails routing conventions: you mount the app, and Rails `at:` decides URL path.
No `host`, `port`, or protocol `path` options are required in API calls.

## Usage

```ruby
# Gemfile
path "/path/to/ruflet/packages" do
  gem "ruflet_rails"
end
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
