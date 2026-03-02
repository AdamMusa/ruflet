# frozen_string_literal: true

module RufletStudio
  module Views
    def nav_bar(page, route)
      selected = {
        "/home" => 0,
        "/gallery" => 1,
        "/settings" => 2
      }[route] || 1

      page.navigation_bar(
        selected_index: selected,
        on_change: ->(e) {
          idx = read_number(e.data, "selected_index") || read_number(e.data, "selectedIndex")
          case idx&.to_i
          when 0
            page.go("/home")
          when 1
            page.go("/gallery")
          when 2
            page.go("/settings")
          end
        },
        destinations: [
          page.navigation_bar_destination(icon: "home", label: "Home"),
          page.navigation_bar_destination(icon: "grid_view", label: "Gallery"),
          page.navigation_bar_destination(icon: "settings", label: "Settings")
        ]
      )
    end
  end
end
