# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_barometer(page, _status)
      return mobile_only_notice(page, "Barometer") unless mobile_platform?(page)

      reading_text = text(value: "Waiting for barometer reading...")
      error_text = text(value: "")

      barometer = page.barometer(
        interval: 200,
        enabled: false,
        cancel_on_error: false,
        on_reading: lambda { |event|
          data = event&.data || {}
          page.update(reading_text, value: barometer_reading_label(data))
          page.update(error_text, value: "")
        },
        on_error: lambda { |event|
          message = event&.data&.dig("message") || event&.data.to_s
          page.update(error_text, value: "Barometer error: #{message}")
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
                button(content: "Start", on_click: ->(_e) { page.update(barometer, enabled: true) }),
                button(content: "Stop", on_click: ->(_e) { page.update(barometer, enabled: false) })
              ]
            )
          ]
        )
      )
    end

    def barometer_reading_label(data)
      pressure = data["pressure"] || data[:pressure]
      value = pressure.is_a?(Numeric) ? format("%.3f", pressure) : pressure.to_s
      "pressure: #{value}"
    end
  end
end
