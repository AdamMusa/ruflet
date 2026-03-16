# frozen_string_literal: true

module RufletStudio
  module SectionsControls
    def build_material_controls(page, status)
      material_dialog = nil
      material_dialog = alert_dialog(
        open: false,
        modal: true,
        title: text(value: "Hello"),
        content: text(value: "Hello from Ruflet"),
        actions: [
          text_button(content: text(value: "OK"), on_click: ->(_e) { page.update(material_dialog, open: false) })
        ]
      )

      build_banner = lambda do
        control(
          :banner,
          open: true,
          leading: icon(icon: "info"),
          content: text(value: "Backup completed successfully."),
          actions: [
            text_button(content: text(value: "Dismiss"), on_click: ->(_e) { page.pop_dialog })
          ]
        )
      end

      column(
        spacing: 12,
        children: [
          status,
          control(
            :card,
            content: container(
              padding: 12,
              content: column(
                spacing: 8,
                children: [
                  text(value: "TextField", style: { size: 14, weight: "w600" }),
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
                children: [
                  text(value: "Buttons", style: { size: 14, weight: "w600" }),
                  row(
                    spacing: 8,
                    children: [
                      filled_button(content: text(value: "Filled"), on_click: ->(_e) { page.update(status, value: "Filled pressed") }),
                      control(:filled_tonal_button, content: text(value: "Tonal"), on_click: ->(_e) { page.update(status, value: "Tonal pressed") }),
                      control(:outlined_button, content: text(value: "Outlined"), on_click: ->(_e) { page.update(status, value: "Outlined pressed") })
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
                children: [
                  text(value: "Selection", style: { size: 14, weight: "w600" }),
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
                children: [
                  text(value: "Dialogs", style: { size: 14, weight: "w600" }),
                  text_button(content: text(value: "Show dialog"), on_click: ->(_e) { page.show_dialog(material_dialog) })
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
                children: [
                  text(value: "Banners", style: { size: 14, weight: "w600" }),
                  text_button(content: text(value: "Show banner"), on_click: ->(_e) {
                    page.show_dialog(build_banner.call)
                  })
                ]
              )
            )
          ),
          control(:list_tile, leading: icon(icon: "info"), title: text(value: "ListTile"))
        ]
      )
    end
  end
end
