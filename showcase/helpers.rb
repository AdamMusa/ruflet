# frozen_string_literal: true

module Showcase
  module Helpers
    # Platforms each native capability actually works on. A feature absent
    # here is assumed available everywhere. Used to guard demos so the user
    # never triggers a "not supported on web" exception — the section shows a
    # clean notice instead.
    FEATURE_PLATFORMS = {
      "directory_picker" => %w[macos windows linux android ios], # not web
      "battery" => %w[android ios],                              # not web/desktop
      "accelerometer" => %w[android ios],
      "gyroscope" => %w[android ios],
      "magnetometer" => %w[android ios],
      "barometer" => %w[android ios],
      "user_accelerometer" => %w[android ios],
      "shake_detector" => %w[android ios],
      "flashlight" => %w[android ios],
      "screen_brightness" => %w[android ios],
      "camera" => %w[android ios],
      "webview" => %w[macos windows linux android ios]           # not web (iframe)
    }.freeze

    def web_platform?(page)
      client_platform(page).downcase == "web"
    end

    def feature_supported?(page, feature)
      platforms = FEATURE_PLATFORMS[feature.to_s]
      return true unless platforms

      platform = client_platform(page).downcase
      return true if platform.empty? # unknown host: don't hide anything

      platforms.include?(platform)
    end

    # Clean placeholder shown in place of a control/section the current
    # platform cannot run, instead of a raw service exception.
    def unsupported_feature_panel(page, title, feature = nil)
      supported = feature ? FEATURE_PLATFORMS[feature.to_s] : nil
      platform = client_platform(page)
      where = platform.to_s.strip.empty? ? "this platform" : platform
      detail =
        if supported
          "Available on #{supported.join(', ')}. Current platform: #{where}."
        else
          "Not available on #{where}."
        end
      container(
        padding: 16,
        border_radius: 12,
        bgcolor: color_panel(page),
        content: column(
          spacing: 6,
          children: [
            row(
              spacing: 8,
              children: [
                icon(Ruflet::MaterialIcons[:info_outline], size: 18, color: color_subtle(page)),
                text(value: title, style: { size: 15, weight: "w600" })
              ]
            ),
            text(value: detail, style: { size: 13, color: color_subtle(page) })
          ]
        )
      )
    end

    # Renders the section body only when the feature is supported here;
    # otherwise a clean notice. Pass a block that builds the real content.
    def with_feature_guard(page, feature, title)
      return unsupported_feature_panel(page, title, feature) unless feature_supported?(page, feature)

      yield
    end

    def github_repo_base
      "https://github.com/AdamMusa/ruflet/blob/main/"
    end

    def github_url_for(path)
      return nil unless path

      source_path = path.to_s.sub(%r{^/}, "")
      source_path = source_path.sub(%r{\Ashowcase/}, "")
      source_path = File.join("ruflet_studio", source_path)
      github_repo_base + source_path
    end

    def github_icon_image(page)
      image(
        src: "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png",
        width: 18,
        height: 18
      )
    end

    def open_github(page, path)
      url = github_url_for(path)
      return unless url

      page.launch_url(
        url,
        mode: "external_application",
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

    def client_platform(page)
      (page.client_details&.dig("platform") || page.client_details&.dig(:platform)).to_s
    end

    def mobile_platform?(page)
      %w[ios android].include?(client_platform(page))
    end

    def permission_handler_platform?(page)
      %w[ios android windows web].include?(client_platform(page))
    end

    def mobile_only_notice(page, feature)
      control(
        :safe_area,
        content: column(
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          spacing: 8,
          children: [
            text(value: "#{feature} is available on iOS and Android devices."),
            text(value: "Current platform: #{client_platform(page).empty? ? "unknown" : client_platform(page)}", style: { size: 12 })
          ]
        )
      )
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

      # Flutter/Flet's GestureDetector emits flat local coords as lx/ly
      # (and global as gx/gy) on tap/tap_down/pan events. Prefer those.
      lx = data["lx"] || data[:lx]
      ly = data["ly"] || data[:ly]
      return { x: lx.to_f, y: ly.to_f } if lx && ly

      gx = data["gx"] || data[:gx]
      gy = data["gy"] || data[:gy]
      return { x: gx.to_f, y: gy.to_f } if gx && gy

      # Fallback for nested {localPosition: {x, y}} style payloads.
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
