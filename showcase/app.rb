# frozen_string_literal: true

require "ruflet"

require_relative "helpers"
require_relative "views/navigation_bar"
require_relative "views/gallery_view"
require_relative "views/home_view"
require_relative "views/settings_view"
require_relative "views/detail_view"
require_relative "views/status_text"
require_relative "sections_controls"
require_relative "sections_media"
require_relative "sections_misc"

module Showcase
  class App < Ruflet::App
    include Helpers
    include Views
    include SectionsControls
    include SectionsMedia
    include SectionsMisc

    def view(page)
      page.title = "Gallery"
      page.scroll = "auto"
      page.bgcolor = color_bg(page)
      page.theme_mode = theme_mode

      page.on_route_change = ->(_e) { render(page) }
      page.on_platform_brightness_change = ->(_e) { render(page) }

      render(page)
    end

    private

    def render(page)
      route = route_path(page.route)
      route = "/gallery" if route == "/"
      page.bgcolor = color_bg(page)
      page.theme_mode = theme_mode

      if route.start_with?("/components/")
        slug = route.split("/").last
        page.views = [detail_view(page, component_title(slug), build_component_detail(page, status_text(page), slug),
                                  source_path: "showcase/sections_controls/components.rb",
                                  back_route: "/components")]
        page.update
        return
      end

      case route
      when "/home"
        page.views = [home_view(page)]
      when "/gallery"
        page.views = [gallery_view(page)]
      when "/settings"
        page.views = [settings_view(page)]
      when "/counter"
        page.views = [detail_view(page, "Counter", build_counter(page, status_text(page)),
                                  source_path: "showcase/sections_controls/counter.rb")]
      when "/todo"
        page.views = [detail_view(page, "To-do", build_todo(page, status_text(page)),
                                  source_path: "showcase/sections_controls/todo.rb")]
      when "/calculator"
        page.views = [detail_view(page, "Calculator", build_calculator(page, status_text(page)),
                                  source_path: "showcase/sections_controls/calculator.rb")]
      when "/components"
        page.views = [detail_view(page, "Components", build_components(page, status_text(page)),
                                  source_path: "showcase/sections_controls/components.rb")]
      when "/drawing"
        page.views = [detail_view(page, "Drawing Tool", build_drawing(page, status_text(page)),
                                  source_path: "showcase/sections_drawing.rb")]
      when "/material"
        page.views = [detail_view(page, "Material controls", build_material_controls(page, status_text(page)),
                                  source_path: "showcase/sections_controls/material_controls.rb")]
      when "/cupertino"
        page.views = [detail_view(page, "Cupertino controls", build_cupertino_controls(page, status_text(page)),
                                  source_path: "showcase/sections_controls/cupertino_controls.rb")]
      when "/charts"
        page.views = [detail_view(page, "Charts", build_charts(page, status_text(page)),
                                  source_path: "showcase/sections_charts.rb")]
      when "/minesweeper"
        page.views = [detail_view(page, "Minesweeper", build_minesweeper(page, status_text(page)),
                                  source_path: "showcase/sections_minesweeper.rb")]
      when "/icon-search"
        page.views = [detail_view(page, "Icon Search", build_icon_search(page, status_text(page)),
                                  source_path: "showcase/sections_misc/icon_search.rb")]
      when "/animation"
        page.views = [detail_view(page, "Ruflet Animation", build_animation(page, status_text(page)),
                                  source_path: "showcase/sections_media/animation.rb")]
      when "/accelerometer"
        page.views = [detail_view(page, "Accelerometer", build_accelerometer(page, status_text(page)),
                                  source_path: "showcase/sections_media/accelerometer.rb")]
      when "/gyroscope"
        page.views = [detail_view(page, "Gyroscope", build_gyroscope(page, status_text(page)),
                                  source_path: "showcase/sections_media/gyroscope.rb")]
      when "/user-accelerometer"
        page.views = [detail_view(page, "User Accelerometer", build_user_accelerometer(page, status_text(page)),
                                  source_path: "showcase/sections_media/user_accelerometer.rb")]
      when "/magnetometer"
        page.views = [detail_view(page, "Magnetometer", build_magnetometer(page, status_text(page)),
                                  source_path: "showcase/sections_media/magnetometer.rb")]
      when "/barometer"
        page.views = [detail_view(page, "Barometer", build_barometer(page, status_text(page)),
                                  source_path: "showcase/sections_media/barometer.rb")]
      when "/browser-context-menu"
        page.views = [detail_view(page, "Browser Context Menu", build_browser_context_menu(page, status_text(page)),
                                  source_path: "showcase/sections_media/browser_context_menu.rb")]
      when "/shake-detector"
        page.views = [detail_view(page, "Shake Detector", build_shake_detector(page, status_text(page)),
                                  source_path: "showcase/sections_media/shake_detector.rb")]
      when "/semantics-service"
        page.views = [detail_view(page, "Semantics Service", build_semantics_service(page, status_text(page)),
                                  source_path: "showcase/sections_media/semantics_service.rb")]
      when "/screenshot"
        page.views = [detail_view(page, "Screenshot", build_screenshot(page, status_text(page)),
                                  source_path: "showcase/sections_media/screenshot.rb")]
      when "/audio"
        page.views = [detail_view(page, "Audio Player", build_audio(page, status_text(page)),
                                  source_path: "showcase/sections_media/audio.rb")]
      when "/audio-recorder"
        page.views = [detail_view(page, "Audio Recorder", build_audio_recorder(page, status_text(page)),
                                  source_path: "showcase/sections_media/audio_recorder.rb")]
      when "/video"
        page.views = [detail_view(page, "Video Player", build_video(page, status_text(page)),
                                  source_path: "showcase/sections_media/video.rb")]
      when "/battery"
        page.views = [detail_view(page, "Battery", build_battery(page, status_text(page)),
                                  source_path: "showcase/sections_media/battery.rb")]
      when "/screen-brightness"
        page.views = [detail_view(page, "Screen Brightness", build_screen_brightness(page, status_text(page)),
                                  source_path: "showcase/sections_media/screen_brightness.rb")]
      when "/clipboard"
        page.views = [detail_view(page, "Clipboard", build_clipboard(page, status_text(page)),
                                  source_path: "showcase/sections_media/clipboard.rb")]
      when "/storage-paths"
        page.views = [detail_view(page, "Storage Paths", build_storage_paths(page, status_text(page)),
                                  source_path: "showcase/sections_media/storage_paths.rb")]
      when "/share"
        page.views = [detail_view(page, "Share", build_share(page, status_text(page)),
                                  source_path: "showcase/sections_media/share.rb")]
      when "/webview"
        page.views = [detail_view(page, "WebView", build_webview(page, status_text(page)),
                                  source_path: "showcase/sections_media/webview.rb",
                                  scroll: nil,
                                  horizontal_alignment: "stretch",
                                  padding: 0)]
      when "/flashlight"
        page.views = [detail_view(page, "Flashlight", build_flashlight(page, status_text(page)),
                                  source_path: "showcase/sections_media/flashlight.rb")]
      when "/camera"
        page.views = [detail_view(page, "Camera", build_camera(page, status_text(page)),
                                  source_path: "showcase/sections_media/camera.rb")]
      when "/connectivity"
        page.views = [detail_view(page, "Connectivity", build_connectivity(page, status_text(page)),
                                  source_path: "showcase/sections_media/connectivity.rb")]
      when "/geolocator"
        page.views = [detail_view(page, "Geolocator", build_geolocator(page, status_text(page)),
                                  source_path: "showcase/sections_media/geolocator.rb")]
      when "/map"
        page.views = [detail_view(page, "Map", build_map(page, status_text(page)),
                                  source_path: "showcase/sections_media/map.rb",
                                  scroll: nil,
                                  horizontal_alignment: "stretch",
                                  padding: 0)]
      when "/permission-handler"
        page.views = [detail_view(page, "Permission Handler", build_permission_handler(page, status_text(page)),
                                  source_path: "showcase/sections_media/permission_handler.rb")]
      when "/secure-storage"
        page.views = [detail_view(page, "Secure Storage", build_secure_storage(page, status_text(page)),
                                  source_path: "showcase/sections_media/secure_storage.rb")]
      when "/file-picker"
        page.views = [detail_view(page, "File Picker", build_file_picker(page, status_text(page)),
                                  source_path: "showcase/sections_media/file_picker.rb")]
      when "/window"
        page.views = [detail_view(page, "Window", build_window(page, status_text(page)),
                                  source_path: "showcase/sections_media/window.rb")]
      else
        page.views = [gallery_view(page)]
      end

      page.update
    end

    def route_path(route)
      route.to_s.split("?").first
    end
  end
end
