# frozen_string_literal: true

module RufletStudio
  module Views
    def settings_view(page)
      route = "/settings"
      gestures_shake = checkbox(value: false)
      gestures_long_press = checkbox(value: false)
      gestures_shake_state = false
      gestures_long_press_state = false
      control(:view,
        route: route,
        bgcolor: color_bg(page),
        appbar: app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: text(value: "Settings", style: { size: 20 }),
          actions: []
        ),
        navigation_bar: nav_bar(page, route),
        padding: 20,
        scroll: "auto",
        children: [
          column(
            spacing: 16,
            children: [
              text(value: "Theme", style: { size: 14 }),
              radio_group(
                value: theme_mode,
                on_change: ->(e) {
                  value =
                    read_string(e.data, "value") ||
                    read_string(e.data, :value) ||
                    read_string(e.data, "selected") ||
                    read_string(e.data, :selected)
                  next unless %w[system light dark].include?(value)

                  set_theme(page, value)
                },
                content: column(
                  spacing: 14,
                  children: [
                    row(
                      alignment: "spaceBetween",
                      children: [
                        row(
                          spacing: 12,
                          children: [
                            icon(icon: "contrast", color: color_icon(page)),
                            text(value: "System")
                          ]
                        ),
                        radio(value: "system")
                      ]
                    ),
                    row(
                      alignment: "spaceBetween",
                      children: [
                        row(
                          spacing: 12,
                          children: [
                            icon(icon: "light_mode", color: color_icon(page)),
                            text(value: "Light")
                          ]
                        ),
                        radio(value: "light")
                      ]
                    ),
                    row(
                      alignment: "spaceBetween",
                      children: [
                        row(
                          spacing: 12,
                          children: [
                            icon(icon: "dark_mode", color: color_icon(page)),
                            text(value: "Dark")
                          ]
                        ),
                        radio(value: "dark")
                      ]
                    )
                  ]
                )
              ),
              container(height: 1, bgcolor: color_divider(page), margin: { top: 8, bottom: 8 }),
              text(value: "Home gestures", style: { size: 14 }),
              control(
                :list_tile,
                leading: icon(icon: "vibration", color: color_icon(page)),
                title: text(value: "Shake device"),
                trailing: gestures_shake,
                on_click: ->(_e) {
                  gestures_shake_state = !gestures_shake_state
                  page.update(gestures_shake, value: gestures_shake_state)
                }
              ),
              control(
                :list_tile,
                leading: icon(icon: "pan_tool_alt", color: color_icon(page)),
                title: text(value: "Long press with two fingers"),
                trailing: gestures_long_press,
                on_click: ->(_e) {
                  gestures_long_press_state = !gestures_long_press_state
                  page.update(gestures_long_press, value: gestures_long_press_state)
                }
              ),
              container(height: 1, bgcolor: color_divider(page), margin: { top: 8, bottom: 8 }),
              text(value: "Application details", style: { size: 14 }),
              row(
                alignment: "spaceBetween",
                children: [
                  text(value: "Client version:"),
                  text(value: "#{Ruflet::VERSION}")
                ]
              ),
              row(
                alignment: "spaceBetween",
                children: [
                  text(value: "Ruflet SDK version:"),
                  text(value: "#{Ruflet::VERSION}")
                ]
              ),
              row(
                alignment: "spaceBetween",
                children: [
                  text(value: "Ruby version:"),
                  text(value: "#{RUBY_VERSION}")
                ]
              )
            ]
          )
        ]
      )
    end
  end
end
