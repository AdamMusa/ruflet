# ruflet_core

`ruflet_core` provides Ruflet's Ruby UI API: controls, control builders, page
operations, events, services, and application lifecycle behavior.

Applications normally receive this package through a generated Ruflet project
or through `ruflet_rails`; it is not a standalone application server.

```ruby
require "ruflet"

Ruflet.run do |page|
  page.title = "Hello"
  page.add(text("Hello Ruflet"))
end
```

Use `ruflet_server` to run a standalone server-driven application. Use
`ruflet_rails` when the UI is hosted by Rails.
