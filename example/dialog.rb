require "ruflet"

class FeedbackSurfacesApp < Ruflet::App
  def view(page)
    page.title = "Feedback Surfaces Demo"

    status = page.text(value: "Ready", size: 14)
    dialog = build_dialog(page, status)
    bottom_sheet = build_bottom_sheet(page, status)

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
                open_surface(page, dialog, status, "Dialog opened")
              }
            ),
            page.button(
              text: "Open snackbar",
              on_click: ->(_e) {
                open_surface(page, build_snack_bar(page, status), status, "SnackBar opened")
              }
            ),
            page.button(
              text: "Open bottom sheet",
              on_click: ->(_e) {
                open_surface(page, bottom_sheet, status, "BottomSheet opened")
              }
            )
          ]
        )
      ),
      appbar: page.app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: page.text(value: "Feedback Surfaces", size: 18)
      )
    )
  end

  private

  def set_status(page, status, value)
    page.update(status, value: value)
  end

  def build_snack_bar(page, status)
    page.snack_bar(
      open: true,
      content: page.text(value: "Profile saved"),
      action: "UNDO",
      on_action: ->(_e) { set_status(page, status, "SnackBar action pressed") },
      on_dismiss: ->(_e) { set_status(page, status, "SnackBar dismissed") }
    )
  end

  def build_dialog(page, status)
    dialog = nil
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
            set_status(page, status, "Dialog closed")
          }
        ),
        page.filled_button(
          text: "Delete",
          on_click: ->(_e) {
            page.update(dialog, open: false)
            set_status(page, status, "Delete action pressed")
          }
        )
      ]
    )
    dialog
  end

  def build_bottom_sheet(page, status)
    bottom_sheet = nil
    bottom_sheet = page.bottom_sheet(
      open: false,
      scrollable: true,
      show_drag_handle: true,
      content: page.container(
        expand: true,
        height: 300,
        width: 600,
        padding: 16,
        content: page.column(
          spacing: 10,
          controls: [
            page.text(value: "Bottom Sheet", size: 24),
            page.text(value: "This is shown using BottomSheet control."),
            page.text(value: "It is intentionally larger in this sample."),
            page.button(
              text: "Close bottom sheet",
              on_click: ->(_e) {
                page.update(bottom_sheet, open: false)
                set_status(page, status, "BottomSheet closed")
              }
            )
          ]
        )
      )
    )
    bottom_sheet
  end

  def open_surface(page, control, status, message)
    page.show_dialog(control)
    set_status(page, status, message)
  end
end

FeedbackSurfacesApp.new.run
