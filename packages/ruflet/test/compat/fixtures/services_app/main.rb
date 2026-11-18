# frozen_string_literal: true

require "ruflet"
require_relative "lib/compat_helpers"

Ruflet.run do |page|
  page.title = CompatHelpers.title
  page.geolocator(on_position_change: ->(_event) {})
  page.secure_storage
  page.add(
    column(
      expand: true,
      controls: [
        text(value: CompatHelpers.greeting, size: 20),
        lottie("assets/animation.json", width: 120, height: 120),
        web_view(url: "https://example.com", expand: true)
      ]
    )
  )
end
