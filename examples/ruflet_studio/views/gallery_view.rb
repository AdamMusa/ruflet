# frozen_string_literal: true

module RufletStudio
  module Views
    def gallery_view(page)
      route = "/gallery"
      page.view(
        route: route,
        bgcolor: "#111318",
        scroll: "auto",
        padding: 8,
        appbar: page.app_bar(
          bgcolor: "#111318",
          color: "#e7e9ec",
          title: page.text(value: "Gallery", size: 20)
        ),
        navigation_bar: nav_bar(page, route),
        controls: [
          page.column(
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
      page.control(
        :list_tile,
        leading: page.icon(name: icon, color: "#cfd4da"),
        title: page.text(value: title, color: "#e7e9ec", size: 16),
        trailing: page.icon(name: "chevron_right", color: "#6c757d"),
        on_click: ->(_e) { page.go(route) }
      )
    end
  end
end
