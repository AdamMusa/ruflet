# frozen_string_literal: true

module RufletStudio
  module Views
    SETTINGS_THEME_OPTIONS = [
      ["contrast", "System", "Match device appearance", "system"],
      ["light_mode", "Light", "Bright surfaces for daytime use", "light"],
      ["dark_mode", "Dark", "Low-glare surfaces with higher contrast", "dark"]
    ].freeze

    def settings_view(page)
      route = "/settings"
      gestures_shake = checkbox(value: false)
      gestures_long_press = checkbox(value: false)
      gestures_shake_state = false
      gestures_long_press_state = false
      control(:view,
        route: route,
        bgcolor: color_bg(page),
        padding: 0,
        appbar: app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: text(value: "Settings", style: { size: 20 }),
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
                padding: 20,
                content: column(
                  scroll: "auto",
                  spacing: 16,
                  horizontal_alignment: "center",
                  children: [
                    settings_section_title(page, "Theme"),
                    settings_card(
                      page,
                      column(
                        spacing: 10,
                        children: SETTINGS_THEME_OPTIONS.map do |icon_name, title, subtitle, value|
                          theme_option_row(page, icon_name, title, subtitle, value)
                        end
                      )
                    ),
                    container(height: 1, bgcolor: color_divider(page), margin: { top: 8, bottom: 8 }),
                    settings_section_title(page, "Home gestures"),
                    control(
                      :list_tile,
                      bgcolor: color_surface(page),
                      leading: icon(icon: "vibration", color: color_icon(page)),
                      title: text(value: "Shake device", style: { color: color_text(page) }),
                      trailing: gestures_shake,
                      on_click: ->(_e) {
                        gestures_shake_state = !gestures_shake_state
                        page.update(gestures_shake, value: gestures_shake_state)
                      }
                    ),
                    control(
                      :list_tile,
                      bgcolor: color_surface(page),
                      leading: icon(icon: "pan_tool_alt", color: color_icon(page)),
                      title: text(value: "Long press with two fingers", style: { color: color_text(page) }),
                      trailing: gestures_long_press,
                      on_click: ->(_e) {
                        gestures_long_press_state = !gestures_long_press_state
                        page.update(gestures_long_press, value: gestures_long_press_state)
                      }
                    ),
                    container(height: 1, bgcolor: color_divider(page), margin: { top: 8, bottom: 8 }),
                    settings_section_title(page, "Application details"),
                    settings_detail_row(page, "Client version:", Ruflet::VERSION),
                    settings_detail_row(page, "Ruflet SDK version:", Ruflet::VERSION),
                    settings_detail_row(page, "Ruby version:", RUBY_VERSION)
                  ]
                )
              ),
              nav_bar(page, route)
            ]
          )
        ]
      )
    end

    def settings_section_title(page, title)
      text(value: title, style: { size: 14, color: color_subtle(page) })
    end

    def settings_card(page, content)
      container(
        bgcolor: color_surface(page),
        border_radius: 18,
        padding: 16,
        border: { width: 1, color: color_divider(page) },
        content: content
      )
    end

    def settings_detail_row(page, label, value)
      row(
        alignment: "spaceBetween",
        children: [
          text(value: label, style: { color: color_text(page) }),
          text(value: value.to_s, style: { color: color_text(page) })
        ]
      )
    end

    def theme_option_row(page, icon_name, title, subtitle, value)
      selected = theme_mode == value

      container(
        bgcolor: selected ? color_panel(page) : color_bg(page),
        border_radius: 14,
        border: { width: 1, color: selected ? color_accent(page) : color_divider(page) },
        padding: { left: 12, right: 12, top: 12, bottom: 12 },
        on_click: ->(_e) { set_theme(page, value) },
        content: row(
          alignment: "spaceBetween",
          vertical_alignment: "center",
          children: [
            row(
              expand: true,
              spacing: 12,
              children: [
                icon(icon: icon_name, color: selected ? color_accent(page) : color_icon(page)),
                column(
                  expand: true,
                  spacing: 2,
                  children: [
                    text(value: title, style: { color: color_text(page) }),
                    text(value: subtitle, style: { size: 12, color: color_subtle(page) })
                  ]
                )
              ]
            ),
            icon(
              icon: selected ? "check_circle" : "radio_button_unchecked",
              color: selected ? color_accent(page) : color_subtle(page)
            )
          ]
        )
      )
    end
  end
end
