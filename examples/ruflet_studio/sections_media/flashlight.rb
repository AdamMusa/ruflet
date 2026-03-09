# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_flashlight(page, status)
      flashlight = page.service(
        :flashlight,
        on_error: ->(e) { page.update(status, value: "Flashlight error: #{e.data}") }
      )
      platform = page.client_details&.dig("platform") || page.client_details&.dig(:platform)

      column(
        spacing: 8,
        children: [
          status,
          row(
            spacing: 8,
            children: [
              text_button(text: "On", on_click: ->(_e) {
                if platform == "ios" || platform == "android"
                  page.invoke(flashlight, "on")
                  page.update(status, value: "Flashlight on")
                else
                  page.update(status, value: "Flashlight requires a real device.")
                end
              }),
              text_button(text: "Off", on_click: ->(_e) {
                if platform == "ios" || platform == "android"
                  page.invoke(flashlight, "off")
                  page.update(status, value: "Flashlight off")
                else
                  page.update(status, value: "Flashlight requires a real device.")
                end
              })
            ]
          )
        ]
      )
    end
  end
end
