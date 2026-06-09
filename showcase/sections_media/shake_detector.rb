# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_shake_detector(page, _status)
      return mobile_only_notice(page, "Shake detector") unless mobile_platform?(page)

      shake_count = 0
      state_text = text(value: "Waiting for shake...")

      page.shake_detector(
        minimum_shake_count: 1,
        shake_count_reset_time_ms: 1_500,
        shake_slop_time_ms: 250,
        shake_threshold_gravity: 1.5,
        on_shake: lambda { |_event|
          shake_count += 1
          page.update(state_text, value: "Shake count: #{shake_count}")
        }
      )

      control(
        :safe_area,
        content: column(
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          spacing: 8,
          children: [
            state_text,
            row(
              alignment: Ruflet::MainAxisAlignment::CENTER,
              spacing: 8,
              children: [
                button(
                  content: "Reset",
                  on_click: lambda { |_e|
                    shake_count = 0
                    page.update(state_text, value: "Waiting for shake...")
                  }
                )
              ]
            )
          ]
        )
      )
    end
  end
end
