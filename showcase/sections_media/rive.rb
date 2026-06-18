# frozen_string_literal: true

module Showcase
  module SectionsMedia
    # Public sample animation hosted by Rive.
    RIVE_SAMPLE_SRC = "https://cdn.rive.app/animations/vehicles.riv"

    def build_rive(page, status)
      return unsupported_feature_panel(page, "Rive", "rive") unless feature_supported?(page, "rive")

      animation = rive(
        RIVE_SAMPLE_SRC,
        width: 300,
        height: 300,
        fit: "contain",
        speed_multiplier: 1.0,
        placeholder: progress_ring()
      )

      column(
        spacing: 12,
        children: [
          status,
          control(:safe_area, content: column(
            spacing: 12,
            children: [
              container(
                width: 300,
                height: 300,
                border_radius: 12,
                bgcolor: color_panel(page),
                content: animation
              ),
              text(value: "Rive animation from #{RIVE_SAMPLE_SRC}", style: { size: 12, color: color_subtle(page) }),
              control(
                :slider,
                min: 0,
                max: 3,
                value: 1,
                divisions: 6,
                label: "Speed = {value}x",
                on_change: ->(e) {
                  page.update(animation, speed_multiplier: read_number(e.data, "value") || 1)
                  page.update(status, value: "Speed #{read_number(e.data, 'value') || 1}x")
                }
              ),
              row(
                spacing: 8,
                children: %w[contain cover fill fit_width fit_height none].map do |fit_value|
                  button(
                    content: text(value: fit_value),
                    on_click: ->(_e) {
                      page.update(animation, fit: fit_value)
                      page.update(status, value: "Fit: #{fit_value}")
                    }
                  )
                end
              )
            ]
          ))
        ]
      )
    end
  end
end
