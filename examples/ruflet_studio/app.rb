# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../packages/ruflet_core/lib", __dir__))
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

module RufletStudio
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
      route = (page.route || "/gallery").split("?").first
      route = "/gallery" if route == "/"
      page.bgcolor = color_bg(page)
      page.theme_mode = theme_mode

      case route
      when "/home"
        page.views = [home_view(page)]
      when "/gallery"
        page.views = [gallery_view(page)]
      when "/settings"
        page.views = [settings_view(page)]
      when "/counter"
        page.views = [detail_view(page, "Counter", build_counter(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_controls
                                  /counter.rb")]
      when "/todo"
        page.views = [detail_view(page, "To-do", build_todo(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_controls/todo.rb")]
      when "/calculator"
        page.views = [detail_view(page, "Calculator", build_calculator(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_controls/calculator.rb")]
      when "/drawing"
        page.views = [detail_view(page, "Drawing Tool", build_drawing(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_drawing.rb")]
      when "/material"
        page.views = [detail_view(page, "Material controls", build_material_controls(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_controls/material_controls.rb")]
      when "/cupertino"
        page.views = [detail_view(page, "Cupertino controls", build_cupertino_controls(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_controls/cupertino_controls.rb")]
      when "/charts"
        page.views = [detail_view(page, "Charts", build_charts(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_charts.rb")]
      when "/minesweeper"
        page.views = [detail_view(page, "Minesweeper", build_minesweeper(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_minesweeper.rb")]
      when "/icon-search"
        page.views = [detail_view(page, "Icon Search", build_icon_search(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_misc/icon_search.rb")]
      when "/animation"
        page.views = [detail_view(page, "Ruflet Animation", build_animation(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/animation.rb")]
      when "/audio"
        page.views = [detail_view(page, "Audio Player", build_audio(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/audio.rb")]
      when "/video"
        page.views = [detail_view(page, "Video Player", build_video(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/video.rb")]
      when "/battery"
        page.views = [detail_view(page, "Battery", build_battery(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/battery.rb")]
      when "/clipboard"
        page.views = [detail_view(page, "Clipboard", build_clipboard(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/clipboard.rb")]
      when "/storage-paths"
        page.views = [detail_view(page, "Storage Paths", build_storage_paths(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/storage_paths.rb")]
      when "/share"
        page.views = [detail_view(page, "Share", build_share(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/share.rb")]
      when "/webview"
        page.views = [detail_view(page, "WebView", build_webview(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/webview.rb",
                                  scroll: nil,
                                  horizontal_alignment: "stretch",
                                  padding: 0)]
      when "/flashlight"
        page.views = [detail_view(page, "Flashlight", build_flashlight(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/flashlight.rb")]
      when "/camera"
        page.views = [detail_view(page, "Camera", build_camera(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/camera.rb")]
      when "/connectivity"
        page.views = [detail_view(page, "Connectivity", build_connectivity(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/connectivity.rb")]
      when "/file-picker"
        page.views = [detail_view(page, "File Picker", build_file_picker(page, status_text(page)),
                                  source_path: "examples/ruflet_studio/sections_media/file_picker.rb")]
      else
        page.views = [gallery_view(page)]
      end

      page.update
    end
  end
end
