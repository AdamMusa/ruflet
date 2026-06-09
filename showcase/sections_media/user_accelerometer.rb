# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_user_accelerometer(page, _status)
      return mobile_only_notice(page, "User accelerometer") unless mobile_platform?(page)

      reading_text = text(value: "Waiting for user accelerometer reading...")
      error_text = text(value: "")

      user_accelerometer = page.user_accelerometer(
        interval: 200,
        cancel_on_error: false,
        on_reading: lambda { |event|
          data = event&.data || {}
          page.update(reading_text, value: sensor_reading_label(data))
          page.update(error_text, value: "")
        },
        on_error: lambda { |event|
          message = event&.data&.dig("message") || event&.data.to_s
          page.update(error_text, value: "User accelerometer error: #{message}")
        }
      )

      control(
        :safe_area,
        content: column(
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          spacing: 8,
          children: [
            reading_text,
            error_text,
            row(
              alignment: Ruflet::MainAxisAlignment::CENTER,
              spacing: 8,
              children: [
                button(content: "Start", on_click: ->(_e) { page.update(user_accelerometer, enabled: true) }),
                button(content: "Stop", on_click: ->(_e) { page.update(user_accelerometer, enabled: false) })
              ]
            )
          ]
        )
      )
    end
  end
end
