# Ruflet Rack

`ruflet_rack` is a thin integration layer for Rack-based apps.

It intentionally does not implement authentication or app-specific helpers. Those remain your backend responsibility (Rails/Sinatra/etc.).

## What it provides

- Rack middleware to store the current request env in thread-local context.
- Runner helper to start Ruflet using Rack context when available.

## Usage

```ruby
require "ruflet_rack"

# Optional: include middleware in your Rack stack
use Ruflet::Rack::Middleware

Ruflet::Rack.run(host: "0.0.0.0", port: 8550) do |page, env|
  # env is nil unless running inside Rack middleware context.
  page.title = "Ruflet + Rack"
end
```

## Rails example

```ruby
# config/application.rb
config.middleware.use Ruflet::Rack::Middleware
```

## Sinatra example

```ruby
use Ruflet::Rack::Middleware
```
