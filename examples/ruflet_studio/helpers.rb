# frozen_string_literal: true

module RufletStudio
  module Helpers
    def github_repo_base
      "https://github.com/AdamMusa/Ruflet/blob/main/"
    end

    def github_url_for(path)
      return nil unless path

      github_repo_base + path.to_s.sub(%r{^/}, "")
    end

    def github_icon_image(page)
      page.image(
        src: "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png",
        width: 18,
        height: 18
      )
    end

    def url_launcher_service(page)
      @url_launcher_services ||= {}
      service = @url_launcher_services[page.object_id]
      return service if service

      service = page.url_launcher
      page.add_service(service)
      @url_launcher_services[page.object_id] = service
      service
    end

    def open_github(page, path)
      url = github_url_for(path)
      return unless url

      service = url_launcher_service(page)

      in_app_supported = page.invoke(
        service,
        "supports_launch_mode",
        args: { "mode" => "in_app_web_view" }
      )

      mode = in_app_supported ? "in_app_web_view" : "external_application"

      page.invoke(
        service,
        "launch_url",
        args: {
          "url" => url,
          "mode" => mode,
          "web_view_configuration" => {
            "enable_javascript" => true,
            "enable_dom_storage" => true
          },
          "web_only_window_name" => "_blank"
        }
      )
    end

    def github_action(page, path)
      page.text_button(
        content: github_icon_image(page),
        on_click: ->(_e) { open_github(page, path) }
      )
    end

    def theme_mode
      @theme_mode ||= "system"
    end

    def effective_theme(page)
      return theme_mode unless theme_mode == "system"

      brightness = page.client_details&.dig("platform_brightness") || page.client_details&.dig(:platform_brightness)
      brightness == "dark" ? "dark" : "light"
    end

    def set_theme(page, mode)
      @theme_mode = %w[system light dark].include?(mode) ? mode : "system"
      page.go(page.route || "/settings")
    end

    def theme_colors(page)
      if effective_theme(page) == "light"
        {
          bg: "#f4f5f7",
          surface: "#ffffff",
          text: "#1f2328",
          subtle: "#6c757d",
          icon: "#495057",
          divider: "#dee2e6"
        }
      else
        {
          bg: "#111318",
          surface: "#111318",
          text: "#e7e9ec",
          subtle: "#9aa0a6",
          icon: "#cfd4da",
          divider: "#2a2e36"
        }
      end
    end


    def color_bg(page) = theme_colors(page)[:bg]
    def color_surface(page) = theme_colors(page)[:surface]
    def color_text(page) = theme_colors(page)[:text]
    def color_subtle(page) = theme_colors(page)[:subtle]
    def color_icon(page) = theme_colors(page)[:icon]
    def color_divider(page) = theme_colors(page)[:divider]

    def read_number(data, key)
      return nil unless data
      return data if data.is_a?(Numeric)
      return data.to_f if data.is_a?(String) && data.match?(/\A-?\d+(\.\d+)?\z/)
      return data[key] if data.is_a?(Hash) && data[key].is_a?(Numeric)
      if data.is_a?(Hash) && data[key]
        return data[key].to_f
      end
      nil
    end

    def read_string(data, key)
      return nil unless data
      return data if data.is_a?(String)
      return data[key] if data.is_a?(Hash) && data[key].is_a?(String)
      nil
    end

    def compute(op1, op2, op)
      v2 = op2.to_f
      case op
      when "+"
        op1 + v2
      when "-"
        op1 - v2
      when "*"
        op1 * v2
      when "/"
        return "Error" if v2.zero?

        op1 / v2
      else
        "Error"
      end
    rescue StandardError
      "Error"
    end

    def fmt_pos(event)
      return "?" unless event&.data

      data = event.data
      if data.is_a?(String)
        begin
          data = JSON.parse(data)
        rescue StandardError
          return event.data.to_s
        end
      end

      return event.data.to_s unless data.is_a?(Hash)

      pos = data["localPosition"] || data["local_position"] || data[:localPosition] || data[:local_position] ||
        data["l"] || data[:l] || data["g"] || data[:g] || data
      if pos.is_a?(Hash)
        x = pos["x"] || pos[:x]
        y = pos["y"] || pos[:y]
        return "#{x}, #{y}" if x && y
      end
      event.data.to_s
    end

    def extract_pos(event)
      return nil unless event&.data

      data = event.data
      if data.is_a?(String)
        begin
          data = JSON.parse(data)
        rescue StandardError
          return nil
        end
      end

      return nil unless data.is_a?(Hash)

      pos = data["localPosition"] || data["local_position"] || data[:localPosition] || data[:local_position] ||
        data["l"] || data[:l] || data["g"] || data[:g] || data
      return nil unless pos.is_a?(Hash)

      x = pos["x"] || pos[:x]
      y = pos["y"] || pos[:y]
      return nil unless x && y

      { x: x.to_f, y: y.to_f }
    end
  end
end
