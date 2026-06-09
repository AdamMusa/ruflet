# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_screen_brightness(page, _status)
      page.screen_brightness(key: "studio_screen_brightness")
      screen_brightness = page.screen_brightness
      info_text = text(value: "Application brightness: -\nSystem brightness: -\nSystem change: -\nAnimate: -\nAuto reset: -")

      fail_info = lambda do |label, error|
        page.update(info_text, value: "#{label} error: #{error}")
      end

      refresh_info = lambda do
        screen_brightness.get_application_screen_brightness(
          on_result: lambda { |application_brightness, application_error|
            if application_error && !application_error.to_s.empty?
              fail_info.call("Application brightness", application_error)
              next
            end

            screen_brightness.get_system_screen_brightness(
              on_result: lambda { |system_brightness, system_error|
                if system_error && !system_error.to_s.empty?
                  fail_info.call("System brightness", system_error)
                  next
                end

                screen_brightness.can_change_system_screen_brightness(
                  on_result: lambda { |can_change, can_change_error|
                    if can_change_error && !can_change_error.to_s.empty?
                      fail_info.call("System change", can_change_error)
                      next
                    end

                    screen_brightness.is_animate(
                      on_result: lambda { |animate, animate_error|
                        if animate_error && !animate_error.to_s.empty?
                          fail_info.call("Animate", animate_error)
                          next
                        end

                        screen_brightness.is_auto_reset(
                          on_result: lambda { |auto_reset, auto_reset_error|
                            if auto_reset_error && !auto_reset_error.to_s.empty?
                              fail_info.call("Auto reset", auto_reset_error)
                              next
                            end

                            page.update(
                              info_text,
                              value: [
                                "Application brightness: #{format_brightness(application_brightness)}",
                                "System brightness: #{format_brightness(system_brightness)}",
                                "System change: #{format_boolean(can_change)}",
                                "Animate: #{format_boolean(animate)}",
                                "Auto reset: #{format_boolean(auto_reset)}"
                              ].join("\n")
                            )
                          }
                        )
                      }
                    )
                  }
                )
              }
            )
          }
        )
      end

      refresh_info.call

      control(
        :safe_area,
        content: column(
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          spacing: 8,
          children: [
            info_text,
            row(
              wrap: true,
              alignment: "center",
              spacing: 8,
              children: [
                button(content: "Refresh", on_click: ->(_e) { refresh_info.call }),
                button(content: "App 50%", on_click: ->(_e) {
                  screen_brightness.set_application_screen_brightness(
                    0.5,
                    on_result: lambda { |_result, error|
                      error && !error.to_s.empty? ? fail_info.call("Application brightness", error) : refresh_info.call
                    }
                  )
                }),
                button(content: "System 50%", on_click: ->(_e) {
                  screen_brightness.set_system_screen_brightness(
                    0.5,
                    on_result: lambda { |_result, error|
                      error && !error.to_s.empty? ? fail_info.call("System brightness", error) : refresh_info.call
                    }
                  )
                }),
                button(content: "Reset app", on_click: ->(_e) {
                  screen_brightness.reset_application_screen_brightness(
                    on_result: lambda { |_result, error|
                      error && !error.to_s.empty? ? fail_info.call("Reset brightness", error) : refresh_info.call
                    }
                  )
                }),
                button(content: "Animate on", on_click: ->(_e) {
                  screen_brightness.set_animate(
                    true,
                    on_result: lambda { |_result, error|
                      error && !error.to_s.empty? ? fail_info.call("Animate", error) : refresh_info.call
                    }
                  )
                }),
                button(content: "Auto reset on", on_click: ->(_e) {
                  screen_brightness.set_auto_reset(
                    true,
                    on_result: lambda { |_result, error|
                      error && !error.to_s.empty? ? fail_info.call("Auto reset", error) : refresh_info.call
                    }
                  )
                })
              ]
            )
          ]
        )
      )
    end

    def format_brightness(value)
      return "Unknown" if value.nil?
      return format("%.2f", value) if value.is_a?(Numeric)

      value.to_s.empty? ? "Unknown" : value.to_s
    end

    def format_boolean(value)
      case value
      when true then "YES"
      when false then "NO"
      else value.to_s.empty? ? "Unknown" : value.to_s.upcase
      end
    end
  end
end
