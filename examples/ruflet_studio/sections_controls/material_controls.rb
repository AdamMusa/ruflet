# frozen_string_literal: true

module RufletStudio
  module SectionsControls
    def build_material_controls(page, status)
      material_dialog = page.alert_dialog(
        open: false,
        modal: true,
        title: page.text(value: "Hello"),
        content: page.text(value: "Hello from Ruflet"),
        actions: [
          page.text_button(text: "OK", on_click: ->(_e) { page.update(material_dialog, open: false) })
        ]
      )

      banner = page.control(
        :banner,
        open: true,
        leading: page.icon(name: "info"),
        content: page.text(value: "Backup completed successfully."),
        actions: [
          page.text_button(text: "Dismiss", on_click: ->(_e) { page.pop_dialog })
        ]
      )

      page.column(
        spacing: 12,
        controls: [
          status,
          page.control(
            :card,
            content: page.container(
              padding: 12,
              content: page.column(
                spacing: 8,
                controls: [
                  page.text(value: "TextField", size: 14, weight: "w600", color: "#e7e9ec"),
                  page.text_field(label: "Name", value: "Ruflet")
                ]
              )
            )
          ),
          page.control(
            :card,
            content: page.container(
              padding: 12,
              content: page.column(
                spacing: 8,
                controls: [
                  page.text(value: "Buttons", size: 14, weight: "w600", color: "#e7e9ec"),
                  page.row(
                    spacing: 8,
                    controls: [
                      page.filled_button(text: "Filled", on_click: ->(_e) { page.update(status, value: "Filled pressed") }),
                      page.control(:filled_tonal_button, text: "Tonal", on_click: ->(_e) { page.update(status, value: "Tonal pressed") }),
                      page.control(:outlined_button, text: "Outlined", on_click: ->(_e) { page.update(status, value: "Outlined pressed") })
                    ]
                  )
                ]
              )
            )
          ),
          page.control(
            :card,
            content: page.container(
              padding: 12,
              content: page.column(
                spacing: 8,
                controls: [
                  page.text(value: "Selection", size: 14, weight: "w600", color: "#e7e9ec"),
                  page.switch(label: "Wi-Fi", value: true),
                  page.control(:slider, min: 0, max: 100, divisions: 10, value: 35, label: "Value = {value}")
                ]
              )
            )
          ),
          page.control(
            :card,
            content: page.container(
              padding: 12,
              content: page.column(
                spacing: 8,
                controls: [
                  page.text(value: "Dialogs", size: 14, weight: "w600", color: "#e7e9ec"),
                  page.text_button(text: "Show dialog", on_click: ->(_e) { page.show_dialog(material_dialog) })
                ]
              )
            )
          ),
          page.control(:list_tile, leading: page.icon(name: "info"), title: page.text(value: "ListTile")),
          banner
        ]
      )
    end
  end
end
