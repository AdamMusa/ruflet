# frozen_string_literal: true

module RufletStudio
  module Views
    def gallery_view(page)
      route = "/gallery"
      widget(
        :view,
        route: route,
        bgcolor: color_bg(page),
        scroll: "auto",
        padding: 8,
        appbar: app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: text(value: "Gallery", size: 20),
          actions: []
        ),
        navigation_bar: nav_bar(page, route),
        controls: [
          column(
            spacing: 6,
            controls: gallery_items(page)
          )
        ]
      )
    end

    def gallery_items(page)
      [
        tile(page, "add", "Counter", "/counter"),
        tile(page, "check", "To-do", "/todo"),
        tile(page, "calculate", "Calculator", "/calculator"),
        tile(page, "brush", "Drawing Tool", "/drawing"),
        tile(page, "view_module", "Material controls", "/material"),
        tile(page, "phone_iphone", "Cupertino controls", "/cupertino"),
        tile(page, "show_chart", "Charts", "/charts"),
        tile(page, "grid_on", "Minesweeper", "/minesweeper"),
        tile(page, "animation", "Ruflet Animation", "/animation"),
        tile(page, "music_note", "Audio Player", "/audio"),
        tile(page, "video_library", "Video Player", "/video"),
        tile(page, "flash_on", "Flashlight", "/flashlight")
      ]
    end

    def tile(page, icon, title, route)
      control(
        :list_tile,
        leading: icon(name: icon, color: color_icon(page)),
        title: text(value: title, color: color_text(page), size: 16),
        trailing: icon(name: "chevron_right", color: color_subtle(page)),
        on_click: ->(_e) { page.go(route) }
      )
    end
  end
end
