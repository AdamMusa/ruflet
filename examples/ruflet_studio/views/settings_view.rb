# frozen_string_literal: true

module RufletStudio
  module Views
    def settings_view(page)
      route = "/settings"
      gestures_shake = page.checkbox(value: false)
      gestures_long_press = page.checkbox(value: false)
      gestures_shake_state = false
      gestures_long_press_state = false
      page.view(
        route: route,
        bgcolor: color_bg(page),
        appbar: page.app_bar(
          bgcolor: color_surface(page),
          color: color_text(page),
          title: page.text(value: "Settings", size: 20),
          actions: []
        ),
        navigation_bar: nav_bar(page, route),
        padding: 20,
        scroll: "auto",
        controls: [
          page.column(
            spacing: 16,
            controls: [
              page.text(value: "Theme", size: 14, color: color_icon(page)),
              page.control(
                :radiogroup,
                value: theme_mode,
                on_change: ->(e) {
                  value = read_string(e.data, "value") || read_string(e.data, "selected") || e.data.to_s
                  set_theme(page, value)
                  page.views = [settings_view(page)]
                  page.update
                },
                content: page.column(
                  spacing: 14,
                  controls: [
                    page.row(
                      alignment: "spaceBetween",
                      controls: [
                        page.row(
                          spacing: 12,
                          controls: [
                            page.icon(name: "contrast", color: color_icon(page)),
                            page.text(value: "System", color: color_text(page))
                          ]
                        ),
                        page.radio(value: "system")
                      ]
                    ),
                    page.row(
                      alignment: "spaceBetween",
                      controls: [
                        page.row(
                          spacing: 12,
                          controls: [
                            page.icon(name: "light_mode", color: color_icon(page)),
                            page.text(value: "Light", color: color_text(page))
                          ]
                        ),
                        page.radio(value: "light")
                      ]
                    ),
                    page.row(
                      alignment: "spaceBetween",
                      controls: [
                        page.row(
                          spacing: 12,
                          controls: [
                            page.icon(name: "dark_mode", color: color_icon(page)),
                            page.text(value: "Dark", color: color_text(page))
                          ]
                        ),
                        page.radio(value: "dark")
                      ]
                    )
                  ]
                )
              ),
              page.container(height: 1, bgcolor: color_divider(page), margin: { top: 8, bottom: 8 }),
              page.text(value: "Home gestures", size: 14, color: color_icon(page)),
              page.control(
                :list_tile,
                leading: page.icon(name: "vibration", color: color_icon(page)),
                title: page.text(value: "Shake device", color: color_text(page)),
                trailing: gestures_shake,
                on_click: ->(_e) {
                  gestures_shake_state = !gestures_shake_state
                  page.update(gestures_shake, value: gestures_shake_state)
                }
              ),
              page.control(
                :list_tile,
                leading: page.icon(name: "pan_tool_alt", color: color_icon(page)),
                title: page.text(value: "Long press with two fingers", color: color_text(page)),
                trailing: gestures_long_press,
                on_click: ->(_e) {
                  gestures_long_press_state = !gestures_long_press_state
                  page.update(gestures_long_press, value: gestures_long_press_state)
                }
              ),
              page.container(height: 1, bgcolor: color_divider(page), margin: { top: 8, bottom: 8 }),
              page.text(value: "Application details", size: 14, color: color_icon(page)),
              page.row(
                alignment: "spaceBetween",
                controls: [
                  page.text(value: "Client version:", color: color_text(page)),
                  page.text(value: "#{Ruflet::VERSION}", color: color_subtle(page))
                ]
              ),
              page.row(
                alignment: "spaceBetween",
                controls: [
                  page.text(value: "Ruflet SDK version:", color: color_text(page)),
                  page.text(value: "#{Ruflet::VERSION}", color: color_subtle(page))
                ]
              ),
              page.row(
                alignment: "spaceBetween",
                controls: [
                  page.text(value: "Ruby version:", color: color_text(page)),
                  page.text(value: "#{RUBY_VERSION}", color: color_subtle(page))
                ]
              )
            ]
          )
        ]
      )
    end
  end
end
