# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_magnetometer(page, _status)
      return mobile_only_notice(page, "Magnetometer") unless mobile_platform?(page)

      reading_text = text(value: "Waiting for magnetometer reading...")
      error_text = text(value: "")

      magnetometer = page.magnetometer(
        interval: 200,
        cancel_on_error: false,
        on_reading: lambda { |event|
          data = event&.data || {}
          page.update(reading_text, value: sensor_reading_label(data))
          page.update(error_text, value: "")
        },
        on_error: lambda { |event|
          message = event&.data&.dig("message") || event&.data.to_s
          page.update(error_text, value: "Magnetometer error: #{message}")
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
                button(content: "Start", on_click: ->(_e) { page.update(magnetometer, enabled: true) }),
                button(content: "Stop", on_click: ->(_e) { page.update(magnetometer, enabled: false) })
              ]
            )
          ]
        )
      )
    end
  end
end
