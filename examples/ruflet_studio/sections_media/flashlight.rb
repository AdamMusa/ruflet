# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_flashlight(page, status)
      flashlight = page.control(:flashlight)

      page.column(
        spacing: 8,
        controls: [
          status,
          page.row(
            spacing: 8,
            controls: [
              page.text_button(text: "On", on_click: ->(_e) {
                page.invoke(flashlight, "on")
                page.update(status, value: "Flashlight on")
              }),
              page.text_button(text: "Off", on_click: ->(_e) {
                page.invoke(flashlight, "off")
                page.update(status, value: "Flashlight off")
              })
            ]
          ),
          flashlight
        ]
      )
    end
  end
end
