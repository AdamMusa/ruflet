# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_flashlight(page, status)
      flashlight = control(
        :flashlight,
        on_error: ->(e) { page.update(status, value: "Flashlight error: #{e.data}") }
      )
      page.add_service(flashlight)
      platform = page.client_details&.dig("platform") || page.client_details&.dig(:platform)

      column(
        spacing: 8,
        controls: [
          status,
          row(
            spacing: 8,
            controls: [
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
