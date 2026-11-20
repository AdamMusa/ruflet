# Docs example: content/docs/rails_integration.md, line 34 (AdamMusa/ruflet_site 05dde18).
# Copied verbatim below this header; do not edit.
RAILS_URL = "https://app.example.com"

Ruflet.run do |page|
  page.add(
    column(
      expand: true,
      controls: [
        text("This header runs in the local Ruflet app"),
        ruflet_app(
          url: RAILS_URL,
          expand: true,
          app_startup_screen_message: "Connecting to Rails…",
          reconnect_timeout_ms: 10_000
        )
      ]
    )
  )
end
