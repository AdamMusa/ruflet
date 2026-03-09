# frozen_string_literal: true

module RufletStudio
  module Views
    def nav_bar(page, route)
      selected = {
        "/home" => 0,
        "/gallery" => 1,
        "/settings" => 2
      }[route] || 1

      navigation_bar(
        bgcolor: color_surface(page),
        indicator_color: color_nav_indicator(page),
        selected_index: selected,
        on_change: ->(e) {
          idx = read_number(e.data, "selected_index") || read_number(e.data, "selectedIndex")
          next if idx.nil? || idx.to_i == selected

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
          navigation_bar_destination(
            icon: "home",
            selected_icon: "home",
            label: "Home"
          ),
          navigation_bar_destination(
            icon: "grid_view",
            selected_icon: "grid_view",
            label: "Gallery"
          ),
          navigation_bar_destination(
            icon: "settings",
            selected_icon: "settings",
            label: "Settings"
          )
        ]
      )
    end
  end
end
