# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_screenshot(page, _status)
      status_text = text(value: "Screenshot control registered.")
      capture_area = page.screenshot(
        tooltip: "Screenshot area",
        content: container(
          width: 260,
          padding: 16,
          bgcolor: color_surface(page),
          content: column(
            spacing: 8,
            horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
            children: [
              icon(icon: Ruflet::MaterialIcons::PHOTO_CAMERA, color: color_icon(page)),
              text(value: "Capture area", style: { size: 18, color: color_text(page) }),
              text(value: "Wrapped by page.screenshot", style: { size: 13, color: color_subtle(page) })
            ]
          )
        )
      )

      control(
        :safe_area,
        content: column(
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          spacing: 10,
          children: [
            capture_area,
            status_text,
            button(
              content: "Refresh",
              on_click: ->(_e) { page.update(status_text, value: "Screenshot control refreshed.") }
            )
          ]
        )
      )
    end
  end
end
