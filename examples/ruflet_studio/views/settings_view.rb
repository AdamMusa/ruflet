# frozen_string_literal: true

module RufletStudio
  module Views
    def settings_view(page)
      route = "/settings"
      gestures_shake = checkbox(value: false)
      gestures_long_press = checkbox(value: false)
      gestures_shake_state = false
      gestures_long_press_state = false
      widget(
        :view,
        route: route,
        bgcolor: color_bg(page),
        appbar: app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: text(value: "Settings", size: 20),
          actions: []
        ),
        navigation_bar: nav_bar(page, route),
        padding: 20,
        scroll: "auto",
        controls: [
          column(
            spacing: 16,
            controls: [
              text(value: "Theme", size: 14, color: color_icon(page)),
              control(
                :radiogroup,
                value: theme_mode,
                on_change: ->(e) {
                  value = read_string(e.data, "value") || read_string(e.data, "selected") || e.data.to_s
                  set_theme(page, value)
                  page.views = [settings_view(page)]
                  page.update
                },
                content: column(
                  spacing: 14,
                  controls: [
                    row(
                      alignment: "spaceBetween",
                      controls: [
                        row(
                          spacing: 12,
                          controls: [
                            icon(name: "contrast", color: color_icon(page)),
                            text(value: "System", color: color_text(page))
                          ]
                        ),
                        radio(value: "system")
                      ]
                    ),
                    row(
                      alignment: "spaceBetween",
                      controls: [
                        row(
                          spacing: 12,
                          controls: [
                            icon(name: "light_mode", color: color_icon(page)),
                            text(value: "Light", color: color_text(page))
                          ]
                        ),
                        radio(value: "light")
                      ]
                    ),
                    row(
                      alignment: "spaceBetween",
                      controls: [
                        row(
                          spacing: 12,
                          controls: [
                            icon(name: "dark_mode", color: color_icon(page)),
                            text(value: "Dark", color: color_text(page))
                          ]
                        ),
                        radio(value: "dark")
                      ]
                    )
                  ]
                )
              ),
              container(height: 1, bgcolor: color_divider(page), margin: { top: 8, bottom: 8 }),
              text(value: "Home gestures", size: 14, color: color_icon(page)),
              control(
                :list_tile,
                leading: icon(name: "vibration", color: color_icon(page)),
                title: text(value: "Shake device", color: color_text(page)),
                trailing: gestures_shake,
                on_click: ->(_e) {
                  gestures_shake_state = !gestures_shake_state
                  page.update(gestures_shake, value: gestures_shake_state)
                }
              ),
              control(
                :list_tile,
                leading: icon(name: "pan_tool_alt", color: color_icon(page)),
                title: text(value: "Long press with two fingers", color: color_text(page)),
                trailing: gestures_long_press,
                on_click: ->(_e) {
                  gestures_long_press_state = !gestures_long_press_state
                  page.update(gestures_long_press, value: gestures_long_press_state)
                }
              ),
              container(height: 1, bgcolor: color_divider(page), margin: { top: 8, bottom: 8 }),
              text(value: "Application details", size: 14, color: color_icon(page)),
              row(
                alignment: "spaceBetween",
                controls: [
                  text(value: "Client version:", color: color_text(page)),
                  text(value: "#{Ruflet::VERSION}", color: color_subtle(page))
                ]
              ),
              row(
                alignment: "spaceBetween",
                controls: [
                  text(value: "Ruflet SDK version:", color: color_text(page)),
                  text(value: "#{Ruflet::VERSION}", color: color_subtle(page))
                ]
              ),
              row(
                alignment: "spaceBetween",
                controls: [
                  text(value: "Ruby version:", color: color_text(page)),
                  text(value: "#{RUBY_VERSION}", color: color_subtle(page))
                ]
              )
            ]
          )
        ]
      )
    end
  end
end
