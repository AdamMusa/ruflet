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
      page.bgcolor = "#111318"

      page.on_route_change = ->(_e) { render(page) }

      render(page)
    end

    private

    def render(page)
      route = (page.route || "/gallery").split("?").first
      route = "/gallery" if route == "/"

      case route
      when "/home"
        page.views = [home_view(page)]
      when "/gallery"
        page.views = [gallery_view(page)]
      when "/settings"
        page.views = [settings_view(page)]
      when "/counter"
        page.views = [detail_view(page, "Counter", build_counter(page, status_text(page)))]
      when "/todo"
        page.views = [detail_view(page, "To-do", build_todo(page, status_text(page)))]
      when "/calculator"
        page.views = [detail_view(page, "Calculator", build_calculator(page, status_text(page)))]
      when "/drawing"
        page.views = [detail_view(page, "Drawing Tool", build_drawing(page, status_text(page)))]
      when "/material"
        page.views = [detail_view(page, "Material controls", build_material_controls(page, status_text(page)))]
      when "/cupertino"
        page.views = [detail_view(page, "Cupertino controls", build_cupertino_controls(page, status_text(page)))]
      when "/charts"
        page.views = [detail_view(page, "Charts", build_charts(page, status_text(page)))]
      when "/minesweeper"
        page.views = [detail_view(page, "Minesweeper", build_minesweeper(page, status_text(page)))]
      when "/animation"
        page.views = [detail_view(page, "Ruflet Animation", build_animation(page, status_text(page)))]
      when "/audio"
        page.views = [detail_view(page, "Audio Player", build_audio(page, status_text(page)))]
      when "/video"
        page.views = [detail_view(page, "Video Player", build_video(page, status_text(page)))]
      when "/flashlight"
        page.views = [detail_view(page, "Flashlight", build_flashlight(page, status_text(page)))]
      else
        page.views = [gallery_view(page)]
      end

      page.update
    end
  end
end
