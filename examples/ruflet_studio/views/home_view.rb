# frozen_string_literal: true

module RufletStudio
  module Views
    def home_view(page)
      route = "/home"
      control(:view,
        route: route,
        bgcolor: color_bg(page),
        appbar: app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: text(value: "Home", style: { size: 20 }),
          actions: []
        ),
        navigation_bar: nav_bar(page, route),
        padding: 16,
        children: [
          text(value: "Home", style: { size: 18 }),
          text(value: "Use the Gallery tab to explore controls.")
        ]
      )
    end
  end
end
