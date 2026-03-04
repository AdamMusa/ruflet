# frozen_string_literal: true

module RufletStudio
  module SectionsControls
    def build_material_controls(page, status)
      material_dialog = alert_dialog(
        open: false,
        modal: true,
        title: text(value: "Hello"),
        content: text(value: "Hello from Ruflet"),
        actions: [
          text_button(text: "OK", on_click: ->(_e) { page.update(material_dialog, open: false) })
        ]
      )

      build_banner = lambda do
        control(
          :banner,
          open: true,
          leading: icon(name: "info"),
          content: text(value: "Backup completed successfully."),
          actions: [
            text_button(text: "Dismiss", on_click: ->(_e) { page.pop_dialog })
          ]
        )
      end

      column(
        spacing: 12,
        controls: [
          status,
          control(
            :card,
            content: container(
              padding: 12,
              content: column(
                spacing: 8,
                controls: [
                  text(value: "TextField", size: 14, weight: "w600", color: "#1f2328"),
                  text_field(label: "Name", value: "Ruflet")
                ]
              )
            )
          ),
          control(
            :card,
            content: container(
              padding: 12,
              content: column(
                spacing: 8,
                controls: [
                  text(value: "Buttons", size: 14, weight: "w600", color: "#1f2328"),
                  row(
                    spacing: 8,
                    controls: [
                      filled_button(text: "Filled", on_click: ->(_e) { page.update(status, value: "Filled pressed") }),
                      control(:filled_tonal_button, text: "Tonal", on_click: ->(_e) { page.update(status, value: "Tonal pressed") }),
                      control(:outlined_button, text: "Outlined", on_click: ->(_e) { page.update(status, value: "Outlined pressed") })
                    ]
                  )
                ]
              )
            )
          ),
          control(
            :card,
            content: container(
              padding: 12,
              content: column(
                spacing: 8,
                controls: [
                  text(value: "Selection", size: 14, weight: "w600", color: "#1f2328"),
                  control(:switch, label: "Wi-Fi", value: true),
                  control(:slider, min: 0, max: 100, divisions: 10, value: 35, label: "Value = {value}")
                ]
              )
            )
          ),
          control(
            :card,
            content: container(
              padding: 12,
              content: column(
                spacing: 8,
                controls: [
                  text(value: "Dialogs", size: 14, weight: "w600", color: "#1f2328"),
                  text_button(text: "Show dialog", on_click: ->(_e) { page.show_dialog(material_dialog) })
                ]
              )
            )
          ),
          control(
            :card,
            content: container(
              padding: 12,
              content: column(
                spacing: 8,
                controls: [
                  text(value: "Banners", size: 14, weight: "w600", color: "#1f2328"),
                  text_button(text: "Show banner", on_click: ->(_e) {
                    page.show_dialog(build_banner.call)
                  })
                ]
              )
            )
          ),
          control(:list_tile, leading: icon(name: "info"), title: text(value: "ListTile"))
        ]
      )
    end
  end
end
