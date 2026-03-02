# frozen_string_literal: true

module RufletStudio
  module Views
    def home_view(page)
      route = "/home"
      page.view(
        route: route,
        bgcolor: "#111318",
        appbar: page.app_bar(
          bgcolor: "#111318",
          color: "#e7e9ec",
          title: page.text(value: "Home", size: 20)
        ),
        navigation_bar: nav_bar(page, route),
        padding: 16,
        controls: [
          page.text(value: "Home", size: 18, color: "#e7e9ec"),
          page.text(value: "Use the Gallery tab to explore controls.", color: "#9aa0a6")
        ]
      )
    end
  end
end
