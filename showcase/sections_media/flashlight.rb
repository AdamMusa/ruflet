# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_flashlight(page, status)
      return mobile_only_notice(page, "Flashlight") unless mobile_platform?(page)

      flashlight = page.service(
        :flashlight,
        on_error: ->(e) { page.update(status, value: "Flashlight error: #{e.data}") }
      )

      column(
        spacing: 8,
        children: [
          status,
          row(
            spacing: 8,
            children: [
              text_button(content: text(value: "On"), on_click: ->(_e) {
                page.invoke(flashlight, "on")
                page.update(status, value: "Flashlight on")
              }),
              text_button(content: text(value: "Off"), on_click: ->(_e) {
                page.invoke(flashlight, "off")
                page.update(status, value: "Flashlight off")
              })
            ]
          )
        ]
      )
    end
  end
end
