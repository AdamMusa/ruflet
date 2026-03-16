# frozen_string_literal: true

module RufletStudio
  module Views
    def gallery_view(page)
      route = "/gallery"
      control(:view,
        route: route,
        bgcolor: color_bg(page),
        padding: 0,
        appbar: app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: text(value: "Gallery", style: { size: 20 }),
          actions: []
        ),
        children: [
          column(
            expand: true,
            spacing: 0,
            children: [
              container(
                expand: true,
                alignment: "center",
                padding: 8,
                content: column(
                  scroll: "auto",
                  spacing: 6,
                  children: gallery_items(page)
                )
              ),
              nav_bar(page, route)
            ]
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
        tile(page, "public", "WebView", "/webview"),
        tile(page, "view_module", "Material controls", "/material"),
        tile(page, "phone_iphone", "Cupertino controls", "/cupertino"),
        tile(page, "show_chart", "Charts", "/charts"),
        tile(page, "grid_on", "Minesweeper", "/minesweeper"),
        tile(page, "search", "Icon Search", "/icon-search"),
        tile(page, "animation", "Ruflet Animation", "/animation"),
        tile(page, "music_note", "Audio Player", "/audio"),
        tile(page, "video_library", "Video Player", "/video"),
        tile(page, "battery_6_bar", "Battery", "/battery"),
        tile(page, "content_paste", "Clipboard", "/clipboard"),
        tile(page, "folder", "Storage Paths", "/storage-paths"),
        tile(page, "share", "Share", "/share"),
        tile(page, "flash_on", "Flashlight", "/flashlight"),
        tile(page, "wifi", "Connectivity", "/connectivity"),
        tile(page, "photo_camera", "Camera", "/camera"),
        tile(page, "attach_file", "File Picker", "/file-picker")
      ]
    end

    def tile(page, icon, title, route)
      control(
        :list_tile,
        bgcolor: color_surface(page),
        content_padding: { left: 12, right: 12, top: 8, bottom: 8 },
        leading: icon(icon: icon, color: color_icon(page)),
        title: text(value: title, style: { size: 16, color: color_text(page) }),
        trailing: icon(icon: "chevron_right", color: color_subtle(page)),
        on_click: ->(_e) { page.go(route) }
      )
    end
  end
end
