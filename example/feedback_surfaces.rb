$LOAD_PATH.unshift(File.expand_path("../packages/ruby_native/lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../packages/ruby_native_ui/lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../packages/ruby_native_server/lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../packages/ruby_native_protocol/lib", __dir__))
require "ruby_native"

class FeedbackSurfacesApp < RubyNative::App
  def view(page)
    page.title = "Feedback Surfaces Demo"

    status = page.text(value: "Ready", size: 14)

    dialog = page.alert_dialog(
      open: false,
      modal: true,
      title: page.text(value: "Delete item?"),
      content: page.text(value: "This demonstrates AlertDialog data shape."),
      actions: [
        page.text_button(
          text: "Cancel",
          on_click: ->(_e) {
            page.update(dialog, open: false)
            page.update(status, value: "Dialog closed")
          }
        ),
        page.filled_button(
          text: "Delete",
          on_click: ->(_e) {
            page.update(dialog, open: false)
            page.update(status, value: "Delete action pressed")
          }
        )
      ]
    )

    snack_bar = page.snack_bar(
      open: false,
      content: page.text(value: "Profile saved"),
      action: "UNDO",
      on_action: ->(_e) { page.update(status, value: "SnackBar action pressed") },
      on_dismiss: ->(_e) { page.update(status, value: "SnackBar dismissed") }
    )

    bottom_sheet = page.bottom_sheet(
      open: false,
      content: page.container(
        padding: 16,
        content: page.column(
          spacing: 10,
          controls: [
            page.text(value: "Bottom Sheet", size: 20),
            page.text(value: "This is shown using BottomSheet control."),
            page.button(
              text: "Close bottom sheet",
              on_click: ->(_e) {
                page.update(bottom_sheet, open: false)
                page.update(status, value: "BottomSheet closed")
              }
            )
          ]
        )
      )
    )

    page.add(
      page.container(
        padding: 16,
        content: page.column(
          spacing: 12,
          controls: [
            page.text(value: "Dialog, SnackBar and BottomSheet", size: 22),
            status,
            page.button(
              text: "Open dialog",
              on_click: ->(_e) {
                page.update(dialog, open: true)
                page.update(status, value: "Dialog opened")
              }
            ),
            page.button(
              text: "Open snackbar",
              on_click: ->(_e) {
                page.update(snack_bar, open: true)
                page.update(status, value: "SnackBar opened")
              }
            ),
            page.button(
              text: "Open bottom sheet",
              on_click: ->(_e) {
                page.update(bottom_sheet, open: true)
                page.update(status, value: "BottomSheet opened")
              }
            )
          ]
        )
      ),
      appbar: page.app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: page.text(value: "Feedback Surfaces", size: 18)
      ),
      dialog: dialog,
      snack_bar: snack_bar,
      bottom_sheet: bottom_sheet
    )
  end
end

FeedbackSurfacesApp.new.run
