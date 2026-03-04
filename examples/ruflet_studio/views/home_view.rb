# frozen_string_literal: true

module RufletStudio
  module Views
    def home_view(page)
      route = "/home"
      widget(
        :view,
        route: route,
        bgcolor: color_bg(page),
        appbar: app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: text(value: "Home", size: 20),
          actions: []
        ),
        navigation_bar: nav_bar(page, route),
        padding: 16,
        controls: [
          text(value: "Home", size: 18, color: color_text(page)),
          text(value: "Use the Gallery tab to explore controls.", color: color_subtle(page))
        ]
      )
    end
  end
end
