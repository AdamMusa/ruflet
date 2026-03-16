require "ruflet"

class FeedbackSurfacesApp < Ruflet::App
  def view(page)
    page.title = "Feedback Surfaces Demo"

    status = text(value: "Ready", style: { size: 14 })
    dialog = build_dialog(page, status)
    bottom_sheet = build_bottom_sheet(page, status)

    page.add(
      container(
        padding: 16,
        content: column(
          spacing: 12,
          children: [
            text(value: "Dialog, SnackBar and BottomSheet", style: { size: 22 }),
            status,
            button(
              content: text(value: "Open dialog"),
              on_click: ->(_e) {
                open_surface(page, dialog, status, "Dialog opened")
              }
            ),
            button(
              content: text(value: "Open snackbar"),
              on_click: ->(_e) {
                open_surface(page, build_snack_bar(page, status), status, "SnackBar opened")
              }
            ),
            button(
              content: text(value: "Open bottom sheet"),
              on_click: ->(_e) {
                open_surface(page, bottom_sheet, status, "BottomSheet opened")
              }
            )
          ]
        )
      ),
      appbar: app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: text(value: "Feedback Surfaces", style: { size: 18 })
      )
    )
  end

  private

  def set_status(page, status, value)
    page.update(status, value: value)
  end

  def build_snack_bar(page, status)
    snack_bar(
      open: true,
      content: text(value: "Profile saved"),
      action: "UNDO",
      duration: duration(seconds: 3),
      on_action: ->(_e) { set_status(page, status, "SnackBar action pressed") },
      on_dismiss: ->(_e) { set_status(page, status, "SnackBar dismissed") }
    )
  end

  def build_dialog(page, status)
    dialog = nil
    dialog = alert_dialog(
      open: false,
      modal: true,
      title: text(value: "Delete item?"),
      content: text(value: "This demonstrates AlertDialog data shape."),
      actions: [
        text_button(
          content: text(value: "Cancel"),
          on_click: ->(_e) do
            page.update(dialog, open: false)
            set_status(page, status, "Dialog closed")
          end
        ),
        filled_button(
          content: text(value: "Delete"),
          on_click: ->(_e) do
            page.update(dialog, open: false)
            set_status(page, status, "Delete action pressed")
          end
        )
      ]
    )
    dialog
  end

  def build_bottom_sheet(page, status)
    bottom_sheet = nil
    bottom_sheet = bottom_sheet(
      open: false,
      scrollable: true,
      show_drag_handle: true,
      content: container(
        expand: true,
        height: 300,
        width: 600,
        padding: 16,
        content: column(
          spacing: 10,
          children: [
            text(value: "Bottom Sheet", style: { size: 24 }),
            text(value: "This is shown using BottomSheet control."),
            text(value: "It is intentionally larger in this sample."),
            button(
              content: text(value: "Close bottom sheet"),
              on_click: ->(_e) do
                page.update(bottom_sheet, open: false)
                set_status(page, status, "BottomSheet closed")
              end
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
