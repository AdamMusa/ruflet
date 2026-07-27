# ruflet_core

`ruflet_core` provides Ruflet's Ruby UI API: controls, control builders, page
operations, events, services, and application lifecycle behavior.

Applications normally receive this package through a generated Ruflet project
or through `ruflet_rails`; it is not a standalone application server.

```ruby
require "ruflet"

Ruflet.run do |page|
  page.title = "Hello"
  page.add(
    container(
      bgcolor: :surface_container_high,
      padding: 24,
      content: text(
        value: "Hello Ruflet",
        style: { color: "DeepOrange500", size: 20, weight: "w600" }
      )
    )
  )
end
```

Color properties accept named colors and hex values. Use Ruby-style symbols
like `:deep_orange_500`, compact strings like `"DeepOrange500"`, spaced names
like `"Deep Orange 500"`, semantic theme names like `:primary_container`, or
hex strings like `"#ff6d00"`. Ruflet normalizes named colors before sending
them to the client.

Use `ruflet_server` to run a standalone server-driven application. Use
`ruflet_rails` when the UI is hosted by Rails.
