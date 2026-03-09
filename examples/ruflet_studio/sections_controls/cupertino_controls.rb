# frozen_string_literal: true

module RufletStudio
  module SectionsControls
    def build_cupertino_controls(page, status)
      cupertino_dialog = control(
        :cupertino_alert_dialog,
        title: text(value: "Cupertino"),
        content: text(value: "Hello from Cupertino"),
        actions: [
          control(:cupertino_dialog_action, content: "OK", on_click: ->(_e) { page.pop_dialog })
        ]
      )

      cupertino_picker = control(
        :cupertino_picker,
        magnification: 1.2,
        use_magnifier: true,
        item_extent: 32,
        children: [
          text(value: "One"),
          text(value: "Two"),
          text(value: "Three")
        ]
      )

      radio_group_control = radio_group(
        value: "r1",
        content: row(
          spacing: 8,
          children: [
            control(:cupertino_radio, label: "Radio 1", value: "r1"),
            control(:cupertino_radio, label: "Radio 2", value: "r2")
          ]
        )
      )

      column(
        spacing: 12,
        children: [
          status,
          control(:cupertino_text_field, label: "Text Field"),
          control(:cupertino_checkbox, label: "Checkbox"),
          control(:cupertino_switch, label: "Switch"),
          control(:cupertino_slider, min: 0, max: 100, divisions: 10, value: 50),
          radio_group_control,
          column(
            spacing: 8,
            children: [
              cupertino_button(
                content: text(value: "Show Dialog"),
                on_click: ->(_e) { page.show_dialog(cupertino_dialog) }
              ),
              cupertino_button(
                content: text(value: "Show Picker"),
                on_click: ->(_e) {
                  page.show_dialog(control(:cupertino_bottom_sheet, content: cupertino_picker, height: 216, padding: { top: 6 }))
                }
              )
            ]
          ),
          column(
            spacing: 8,
            children: [
              cupertino_button(
                content: text(value: "Show DatePicker"),
                on_click: ->(_e) {
                  page.show_dialog(control(:cupertino_bottom_sheet, content: control(:cupertino_date_picker), height: 216, padding: { top: 6 }))
                }
              ),
              cupertino_button(
                content: text(value: "Show TimerPicker"),
                on_click: ->(_e) {
                  page.show_dialog(control(:cupertino_bottom_sheet, content: control(:cupertino_timer_picker), height: 216, padding: { top: 6 }))
                }
              )
            ]
          )
        ]
      )
    end
  end
end
