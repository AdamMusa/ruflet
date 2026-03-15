# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_battery(page, _status)
      info_text = text(value: "Battery level: -\nBattery state: -\nBattery saver: -")

      refresh_info = lambda do
        page.get_battery_level(
          timeout: nil,
          on_result: lambda { |level, level_error|
            if level_error && !level_error.to_s.empty?
              page.update(info_text, value: "Battery error: #{level_error}")
              next
            end

            page.get_battery_state(
              timeout: nil,
              on_result: lambda { |state, state_error|
                if state_error && !state_error.to_s.empty?
                  page.update(info_text, value: "Battery error: #{state_error}")
                  next
                end

                page.battery_save_mode?(
                  timeout: nil,
                  on_result: lambda { |save_mode, save_error|
                    if save_error && !save_error.to_s.empty?
                      page.update(info_text, value: "Battery error: #{save_error}")
                      next
                    end

                    level_label = level.nil? ? "Unknown" : "#{level}%"
                    state_label = state.to_s.empty? ? "unknown" : state.to_s.upcase
                    saver_label = save_mode ? "ON" : "OFF"
                    page.update(
                      info_text,
                      value: "Battery level: #{level_label}\nBattery state: #{state_label}\nBattery saver: #{saver_label}"
                    )
                  }
                )
              }
            )
          }
        )
      end

      battery = page.service(:battery)
      battery.on(:state_change) { |_e| refresh_info.call }
      refresh_info.call

      control(
        :safe_area,
        content: column(
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          children: [
            info_text,
            button(
              content: "Refresh battery info",
              on_click: ->(_e) { refresh_info.call }
            )
          ]
        )
      )
    end
  end
end
