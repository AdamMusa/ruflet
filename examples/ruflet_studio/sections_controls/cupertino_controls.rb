# frozen_string_literal: true

module RufletStudio
  module SectionsControls
    def build_cupertino_controls(page, status)
      radio_group = page.radio_group(value: "r1")
      cupertino_dialog = page.control(
        :cupertino_alert_dialog,
        title: page.text(value: "Cupertino"),
        content: page.text(value: "Hello from Cupertino"),
        actions: [
          page.control(:cupertino_dialog_action, text: "OK", on_click: ->(_e) { page.pop_dialog })
        ]
      )

      cupertino_picker = page.control(
        :cupertino_picker,
        magnification: 1.2,
        use_magnifier: true,
        item_extent: 32,
        controls: [
          page.text(value: "One", color: "#111318"),
          page.text(value: "Two", color: "#111318"),
          page.text(value: "Three", color: "#111318")
        ]
      )

      page.column(
        spacing: 12,
        controls: [
          status,
          page.control(:cupertino_text_field, label: "Text Field"),
          page.control(:cupertino_checkbox, label: "Checkbox"),
          page.control(:cupertino_switch, label: "Switch"),
          page.control(:cupertino_slider, min: 0, max: 100, divisions: 10, value: 50),
          page.row(
            spacing: 8,
            controls: [
              page.control(:cupertino_radio, label: "Radio 1", value: "r1", group: radio_group),
              page.control(:cupertino_radio, label: "Radio 2", value: "r2", group: radio_group)
            ]
          ),
          page.column(
            spacing: 8,
            controls: [
              page.cupertino_button(
                content: page.text(value: "Show Dialog"),
                on_click: ->(_e) { page.show_dialog(cupertino_dialog) }
              ),
              page.cupertino_button(
                content: page.text(value: "Show Picker"),
                on_click: ->(_e) {
                  page.show_dialog(page.control(:cupertino_bottom_sheet, content: cupertino_picker, height: 216, padding: { top: 6 }))
                }
              )
            ]
          ),
          page.column(
            spacing: 8,
            controls: [
              page.cupertino_button(
                content: page.text(value: "Show DatePicker"),
                on_click: ->(_e) {
                  page.show_dialog(page.control(:cupertino_bottom_sheet, content: page.control(:cupertino_date_picker), height: 216, padding: { top: 6 }))
                }
              ),
              page.cupertino_button(
                content: page.text(value: "Show TimerPicker"),
                on_click: ->(_e) {
                  page.show_dialog(page.control(:cupertino_bottom_sheet, content: page.control(:cupertino_timer_picker), height: 216, padding: { top: 6 }))
                }
              )
            ]
          )
        ]
      )
    end
  end
end
