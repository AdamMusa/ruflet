# frozen_string_literal: true

module Showcase
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
        tile(page, Ruflet::MaterialIcons::ADD, "Counter", "/counter"),
        tile(page, Ruflet::MaterialIcons::CHECK, "To-do", "/todo"),
        tile(page, Ruflet::MaterialIcons::CALCULATE, "Calculator", "/calculator"),
        tile(page, Ruflet::MaterialIcons::CODE, "Code Editor", "/code-editor"),
        tile(page, Ruflet::MaterialIcons::VIEW_COLUMN, "Responsive Row", "/responsive-row"),
        tile(page, Ruflet::MaterialIcons::ANIMATION, "Rive", "/rive"),
        tile(page, Ruflet::MaterialIcons::VIEW_MODULE, "Components", "/components"),
        tile(page, Ruflet::MaterialIcons::BRUSH, "Drawing Tool", "/drawing"),
        tile(page, Ruflet::MaterialIcons::PUBLIC, "WebView", "/webview"),
        tile(page, Ruflet::MaterialIcons::VIEW_MODULE, "Material controls", "/material"),
        tile(page, Ruflet::MaterialIcons::PHONE_IPHONE, "Cupertino controls", "/cupertino"),
        tile(page, Ruflet::MaterialIcons::SHOW_CHART, "Charts", "/charts"),
        tile(page, Ruflet::MaterialIcons::GRID_ON, "Minesweeper", "/minesweeper"),
        tile(page, Ruflet::MaterialIcons::SEARCH, "Icon Search", "/icon-search"),
        tile(page, Ruflet::MaterialIcons::ANIMATION, "Ruflet Animation", "/animation"),
        tile(page, Ruflet::MaterialIcons::SPEED, "Accelerometer", "/accelerometer"),
        tile(page, Ruflet::MaterialIcons::SCREEN_ROTATION, "Gyroscope", "/gyroscope"),
        tile(page, Ruflet::MaterialIcons::DIRECTIONS_RUN, "User Accelerometer", "/user-accelerometer"),
        tile(page, Ruflet::MaterialIcons::EXPLORE, "Magnetometer", "/magnetometer"),
        tile(page, Ruflet::MaterialIcons::AIR, "Barometer", "/barometer"),
        tile(page, Ruflet::MaterialIcons::PUBLIC, "Browser Context Menu", "/browser-context-menu"),
        tile(page, Ruflet::MaterialIcons::VIBRATION, "Shake Detector", "/shake-detector"),
        tile(page, Ruflet::MaterialIcons::ACCESSIBILITY, "Semantics Service", "/semantics-service"),
        tile(page, Ruflet::MaterialIcons::SCREENSHOT, "Screenshot", "/screenshot"),
        tile(page, Ruflet::MaterialIcons::MUSIC_NOTE, "Audio Player", "/audio"),
        tile(page, Ruflet::MaterialIcons[:mic], "Audio Recorder", "/audio-recorder"),
        tile(page, Ruflet::MaterialIcons::VIDEO_LIBRARY, "Video Player", "/video"),
        tile(page, Ruflet::MaterialIcons::BATTERY_6_BAR, "Battery", "/battery"),
        tile(page, Ruflet::MaterialIcons::BRIGHTNESS_6, "Screen Brightness", "/screen-brightness"),
        tile(page, Ruflet::MaterialIcons::CONTENT_PASTE, "Clipboard", "/clipboard"),
        tile(page, Ruflet::MaterialIcons::FOLDER, "Storage Paths", "/storage-paths"),
        tile(page, Ruflet::MaterialIcons::SHARE, "Share", "/share"),
        tile(page, Ruflet::MaterialIcons::FLASH_ON, "Flashlight", "/flashlight"),
        tile(page, Ruflet::MaterialIcons::WIFI, "Connectivity", "/connectivity"),
        tile(page, Ruflet::MaterialIcons[:location_on], "Geolocator", "/geolocator"),
        tile(page, Ruflet::MaterialIcons::MAP, "Map", "/map"),
        tile(page, Ruflet::MaterialIcons[:admin_panel_settings], "Permission Handler", "/permission-handler"),
        tile(page, Ruflet::MaterialIcons[:lock], "Secure Storage", "/secure-storage"),
        tile(page, Ruflet::MaterialIcons::PHOTO_CAMERA, "Camera", "/camera"),
        tile(page, Ruflet::MaterialIcons::ATTACH_FILE, "File Picker", "/file-picker"),
        tile(page, Ruflet::MaterialIcons::VIEW_MODULE, "Window", "/window")
      ]
    end

    def tile(page, icon_value, title, route)
      control(
        :list_tile,
        bgcolor: color_surface(page),
        content_padding: { left: 12, right: 12, top: 8, bottom: 8 },
        leading: icon(icon: icon_value, color: color_icon(page)),
        title: text(value: title, style: { size: 16, color: color_text(page) }),
        trailing: icon(icon: Ruflet::MaterialIcons::CHEVRON_RIGHT, color: color_subtle(page)),
        on_click: ->(_e) { page.go(route) }
      )
    end
  end
end
