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
        indicator_color: effective_theme(page) == "light" ? "#dbe4ff" : "#2b3036",
        label_text_style: { size: 12, color: color_subtle(page) },
        selected_label_text_style: { size: 12, color: color_text(page) },
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
          navigation_bar_destination(icon: "home", label: "Home", icon_color: color_subtle(page), selected_icon_color: color_text(page)),
          navigation_bar_destination(icon: "grid_view", label: "Gallery", icon_color: color_subtle(page), selected_icon_color: color_text(page)),
          navigation_bar_destination(icon: "settings", label: "Settings", icon_color: color_subtle(page), selected_icon_color: color_text(page))
        ]
      )
    end
  end
end
