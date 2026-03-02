# frozen_string_literal: true

module RufletStudio
  module Views
    def settings_view(page)
      route = "/settings"
      theme_group = page.radio_group(value: "system")
      gestures_shake = page.checkbox(value: false)
      gestures_long_press = page.checkbox(value: false)
      gestures_shake_state = false
      gestures_long_press_state = false
      page.view(
        route: route,
        bgcolor: "#111318",
        appbar: page.app_bar(
          bgcolor: "#111318",
          color: "#e7e9ec",
          title: page.text(value: "Settings", size: 20)
        ),
        navigation_bar: nav_bar(page, route),
        padding: 20,
        scroll: "auto",
        controls: [
          page.column(
            spacing: 16,
            controls: [
              page.text(value: "Theme", size: 14, color: "#cfd4da"),
              page.control(
                :radiogroup,
                value: "system",
                content: page.column(
                  spacing: 14,
                  controls: [
                    page.row(
                      alignment: "spaceBetween",
                      controls: [
                        page.row(
                          spacing: 12,
                          controls: [
                            page.icon(name: "contrast", color: "#cfd4da"),
                            page.text(value: "System", color: "#e7e9ec")
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
                            page.icon(name: "light_mode", color: "#cfd4da"),
                            page.text(value: "Light", color: "#e7e9ec")
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
                            page.icon(name: "dark_mode", color: "#cfd4da"),
                            page.text(value: "Dark", color: "#e7e9ec")
                          ]
                        ),
                        page.radio(value: "dark")
                      ]
                    )
                  ]
                )
              ),
              page.container(height: 1, bgcolor: "#2a2e36", margin: { top: 8, bottom: 8 }),
              page.text(value: "Home gestures", size: 14, color: "#cfd4da"),
              page.control(
                :list_tile,
                leading: page.icon(name: "vibration", color: "#cfd4da"),
                title: page.text(value: "Shake device", color: "#e7e9ec"),
                trailing: gestures_shake,
                on_click: ->(_e) {
                  gestures_shake_state = !gestures_shake_state
                  page.update(gestures_shake, value: gestures_shake_state)
                }
              ),
              page.control(
                :list_tile,
                leading: page.icon(name: "pan_tool_alt", color: "#cfd4da"),
                title: page.text(value: "Long press with two fingers", color: "#e7e9ec"),
                trailing: gestures_long_press,
                on_click: ->(_e) {
                  gestures_long_press_state = !gestures_long_press_state
                  page.update(gestures_long_press, value: gestures_long_press_state)
                }
              ),
              page.container(height: 1, bgcolor: "#2a2e36", margin: { top: 8, bottom: 8 }),
              page.text(value: "Application details", size: 14, color: "#cfd4da"),
              page.row(
                alignment: "spaceBetween",
                controls: [
                  page.text(value: "Client version:", color: "#e7e9ec"),
                  page.text(value: "#{Ruflet::VERSION}", color: "#9aa0a6")
                ]
              ),
              page.row(
                alignment: "spaceBetween",
                controls: [
                  page.text(value: "Ruflet SDK version:", color: "#e7e9ec"),
                  page.text(value: "#{Ruflet::VERSION}", color: "#9aa0a6")
                ]
              ),
              page.row(
                alignment: "spaceBetween",
                controls: [
                  page.text(value: "Ruby version:", color: "#e7e9ec"),
                  page.text(value: "#{RUBY_VERSION}", color: "#9aa0a6")
                ]
              )
            ]
          )
        ]
      )
    end
  end
end
