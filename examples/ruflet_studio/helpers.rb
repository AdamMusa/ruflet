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
      image(
        src: "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png",
        width: 18,
        height: 18
      )
    end

    def url_launcher_service(page)
      page.service(:url_launcher)
    end

    def open_github(page, path)
      url = github_url_for(path)
      return unless url

      url_launcher_service(page)
      page.launch_url(
        url,
        on_result: lambda { |_result, error|
          Kernel.warn("GitHub URL launch failed: #{error}") if error && !error.to_s.empty?
        }
      )
    end

    def github_action(page, path)
      text_button(
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
      normalized = mode.to_s.strip.downcase
      return unless %w[system light dark].include?(normalized)

      @theme_mode = normalized
      page.theme_mode = normalized
      page.go(page.route || "/settings")
    end

    def theme_colors(page)
      if effective_theme(page) == "light"
        {
          bg: "#edf3fb",
          surface: "#ffffff",
          text: "#1f2328",
          subtle: "#475467",
          icon: "#475467",
          divider: "#cad5e5",
          panel: "#dce6f5",
          nav_indicator: "#bfd3ff",
          accent: "#2563eb"
        }
      else
        {
          bg: "#0b1220",
          surface: "#111827",
          text: "#e5edf7",
          subtle: "#94a3b8",
          icon: "#cbd5e1",
          divider: "#233044",
          panel: "#172033",
          nav_indicator: "#1d4ed8",
          accent: "#60a5fa"
        }
      end
    end


    def color_bg(page) = theme_colors(page)[:bg]
    def color_surface(page) = theme_colors(page)[:surface]
    def color_text(page) = theme_colors(page)[:text]
    def color_subtle(page) = theme_colors(page)[:subtle]
    def color_icon(page) = theme_colors(page)[:icon]
    def color_divider(page) = theme_colors(page)[:divider]
    def color_panel(page) = theme_colors(page)[:panel]
    def color_nav_indicator(page) = theme_colors(page)[:nav_indicator]
    def color_accent(page) = theme_colors(page)[:accent]

    def read_number(data, key)
      return nil unless data
      return data if data.is_a?(Numeric)
      return data.to_f if data.is_a?(String) && data.match?(/\A-?\d+(\.\d+)?\z/)
      if data.is_a?(Hash)
        raw = data[key] || data[key.to_s] || data[key.to_sym]
        return raw if raw.is_a?(Numeric)
        return raw.to_f if raw
      end
      nil
    end

    def read_string(data, key)
      return nil unless data
      return data if data.is_a?(String)
      if data.is_a?(Hash)
        raw = data[key] || data[key.to_s] || data[key.to_sym]
        return raw if raw.is_a?(String)
      end
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
