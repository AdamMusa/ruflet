# frozen_string_literal: true

module Showcase
  module Views
    STUDIO_NAV_ITEMS = [
      [Ruflet::MaterialIcons::HOME, "Home", "/home"],
      [Ruflet::MaterialIcons::GRID_VIEW, "Gallery", "/gallery"],
      [Ruflet::MaterialIcons::SETTINGS, "Settings", "/settings"]
    ].freeze

    def nav_bar(page, route)
      selected = STUDIO_NAV_ITEMS.index { |_icon, _label, item_route| item_route == route } || 1
      container(
        bgcolor: color_panel(page),
        border: { width: 1, color: color_divider(page) },
        padding: { left: 12, right: 12, top: 10, bottom: 12 },
        content: row(
          spacing: 12,
          children: STUDIO_NAV_ITEMS.each_with_index.map do |(icon_value, label, item_route), index|
            nav_tab(page, index, selected, icon_value, label, item_route)
          end
        )
      )
    end

    def nav_tab(page, index, selected, icon_value, label, route)
      active = index == selected

      container(
        expand: true,
        border_radius: 18,
        bgcolor: color_panel(page),
        padding: { top: 10, bottom: 8, left: 8, right: 8 },
        on_click: ->(_e) { page.go(route) },
        content: column(
          horizontal_alignment: "center",
          spacing: 6,
          children: [
            icon(
              icon: icon_value,
              color: active ? color_accent(page) : color_subtle(page)
            ),
            text(
              value: label,
              style: {
                size: 13,
                weight: active ? "w600" : "w500",
                color: active ? color_accent(page) : color_subtle(page)
              }
            ),
            container(
              width: 36,
              height: 3,
              border_radius: 99,
              bgcolor: active ? color_accent(page) : color_panel(page)
            )
          ]
        )
      )
    end
  end
end
