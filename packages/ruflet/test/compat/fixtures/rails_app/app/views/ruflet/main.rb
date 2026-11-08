# frozen_string_literal: true

# The home screen for this Ruflet app. You own this file; nothing is
# auto-discovered. It is mounted explicitly in config/routes.rb:
#   match "/ws", to: Ruflet::Rails.native(Rails.root.join("app/views/ruflet/main.rb")), via: :all
Ruflet.run do |page|
  page.title = "Rails App"
  page.add(
    safe_area(
      container(
        expand: true,
        padding: 24,
        content: column(
          spacing: 12,
          controls: [
            text("Rails App", size: 24, weight: "bold"),
            text("Edit app/views/ruflet/main.rb to build your app.")
          ]
        )
      ),
      expand: true
    )
  )
end
