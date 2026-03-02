# frozen_string_literal: true

require "ruflet"

class StudioGalleryApp < Ruflet::App
  def view(page)
    page.title = "Studio Gallery"
    page.scroll = "auto"
    page.bgcolor = "#f4f5f8"

    status = page.text(value: "Ready", size: 12, color: "#6b6f76")

    dialog = build_dialog(page, status)
    bottom_sheet = build_bottom_sheet(page, status)

    navigation_bar = page.navigation_bar(
      selected_index: 0,
      destinations: [
        page.navigation_bar_destination(icon: "home", label: "Home"),
        page.navigation_bar_destination(icon: "photo", label: "Media"),
        page.navigation_bar_destination(icon: "settings", label: "Settings")
      ]
    )

    page.add(
      page.container(
        padding: 16,
        content: page.column(
          spacing: 14,
          controls: [
            header_block(page, status),
            section(
              page,
              "Layout",
              "Row, Column, Stack, Container",
              [
                page.row(
                  spacing: 8,
                  controls: [
                    color_chip(page, "#ff6b6b", "A"),
                    color_chip(page, "#4dabf7", "B"),
                    color_chip(page, "#51cf66", "C")
                  ]
                ),
                page.stack(
                  width: 150,
                  height: 90,
                  controls: [
                    page.container(width: 150, height: 90, bgcolor: "#e9ecef", border_radius: 12),
                    page.container(width: 110, height: 60, bgcolor: "#adb5bd", border_radius: 10),
                    page.container(width: 70, height: 30, bgcolor: "#495057", border_radius: 8)
                  ]
                )
              ]
            ),
            section(
              page,
              "Typography",
              "Text + Markdown",
              [
                page.text(value: "Headline Example", size: 20, weight: "w600"),
                page.markdown("**Markdown** with `code`, _emphasis_ and a [link](https://example.com).")
              ]
            ),
            section(
              page,
              "Buttons",
              "Material button types + icons",
              [
                page.row(
                  spacing: 8,
                  controls: [
                    page.button(text: "Button", on_click: ->(_e) { set_status(page, status, "Button clicked") }),
                    page.text_button(text: "Text", on_click: ->(_e) { set_status(page, status, "Text button") }),
                    page.filled_button(text: "Filled", on_click: ->(_e) { set_status(page, status, "Filled button") }),
                    page.icon_button(icon: "favorite", on_click: ->(_e) { set_status(page, status, "Icon button") })
                  ]
                )
              ]
            ),
            section(
              page,
              "Inputs",
              "Text field, checkbox, radio group",
              [
                page.text_field(
                  label: "Search",
                  hint_text: "Type here",
                  on_change: ->(e) { set_status(page, status, "Text changed: #{e.data}") }
                ),
                page.row(
                  spacing: 12,
                  controls: [
                    page.checkbox(
                      label: "Email alerts",
                      value: true,
                      on_change: ->(e) { set_status(page, status, "Checkbox: #{e.data}") }
                    ),
                    page.checkbox(
                      label: "Weekly digest",
                      value: false,
                      on_change: ->(e) { set_status(page, status, "Checkbox: #{e.data}") }
                    )
                  ]
                ),
                page.radio_group(
                  value: "alpha",
                  content: page.row(
                    spacing: 12,
                    controls: [
                      page.radio(value: "alpha", label: "Alpha"),
                      page.radio(value: "beta", label: "Beta"),
                      page.radio(value: "gamma", label: "Gamma")
                    ]
                  ),
                  on_change: ->(e) { set_status(page, status, "Radio: #{e.data}") }
                )
              ]
            ),
            section(
              page,
              "Gestures + Drag",
              "GestureDetector, Draggable, DragTarget",
              [
                page.gesture_detector(
                  on_tap: ->(_e) { set_status(page, status, "Gesture tapped") },
                  content: page.container(
                    padding: 12,
                    bgcolor: "#e7f5ff",
                    border_radius: 10,
                    content: page.text(value: "Tap this card", size: 14)
                  )
                ),
                drag_row(page, status)
              ]
            ),
            section(
              page,
              "Feedback",
              "Dialog, SnackBar, BottomSheet",
              [
                page.row(
                  spacing: 8,
                  controls: [
                    page.button(
                      text: "Dialog",
                      on_click: ->(_e) { open_surface(page, dialog, status, "Dialog opened") }
                    ),
                    page.button(
                      text: "SnackBar",
                      on_click: ->(_e) { open_surface(page, build_snack_bar(page, status), status, "SnackBar opened") }
                    ),
                    page.button(
                      text: "BottomSheet",
                      on_click: ->(_e) { open_surface(page, bottom_sheet, status, "BottomSheet opened") }
                    )
                  ]
                )
              ]
            ),
            section(
              page,
              "Navigation",
              "Tabs + NavigationBar",
              [
                page.tabs(
                  height: 160,
                  tabs: [
                    page.tab(label: "Overview", content: page.text(value: "Overview content")),
                    page.tab(label: "Details", content: page.text(value: "Details content")),
                    page.tab(label: "Stats", content: page.text(value: "Stats content"))
                  ]
                ),
                page.text(value: "NavigationBar shown at bottom.", size: 12, color: "#6b6f76")
              ]
            ),
            section(
              page,
              "Media",
              "Image + Icon",
              [
                page.row(
                  spacing: 10,
                  controls: [
                    page.image(src: "assets/splash.png", width: 120, height: 80, fit: "cover"),
                    page.image(
                      src: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=400",
                      width: 120,
                      height: 80,
                      fit: "cover"
                    )
                  ]
                ),
                page.row(
                  spacing: 12,
                  controls: [
                    page.icon(name: "photo", size: 24, color: "#495057"),
                    page.icon(name: "favorite", size: 24, color: "#fa5252"),
                    page.icon(name: "explore", size: 24, color: "#1c7ed6")
                  ]
                )
              ]
            ),
            section(
              page,
              "Cupertino",
              "iOS-styled controls",
              [
                page.row(
                  spacing: 8,
                  controls: [
                    page.cupertino_button(text: "Cupertino"),
                    page.cupertino_filled_button(text: "Filled")
                  ]
                ),
                page.cupertino_text_field(placeholder: "Cupertino text field"),
                page.row(
                  spacing: 12,
                  controls: [
                    page.cupertino_switch(value: true, on_change: ->(e) { set_status(page, status, "Cupertino switch: #{e.data}") }),
                    page.cupertino_slider(
                      value: 40,
                      on_change: ->(e) { set_status(page, status, "Cupertino slider: #{e.data}") }
                    )
                  ]
                )
              ]
            )
          ]
        )
      ),
      appbar: page.app_bar(
        bgcolor: "#ffffff",
        color: "#1f2328",
        title: page.text(value: "Studio Gallery", size: 18)
      ),
      navigation_bar: navigation_bar
    )
  end

  private

  def header_block(page, status)
    page.container(
      padding: 14,
      bgcolor: "#ffffff",
      border_radius: 12,
      border: { width: 1, color: "#e1e4ea" },
      content: page.column(
        spacing: 6,
        controls: [
          page.text(value: "Studio Gallery", size: 22, weight: "w700"),
          page.text(value: "Ruflet controls showcase", size: 14, color: "#6b6f76"),
          status
        ]
      )
    )
  end

  def section(page, title, subtitle, items)
    page.container(
      padding: 12,
      bgcolor: "#ffffff",
      border_radius: 12,
      border: { width: 1, color: "#e1e4ea" },
      content: page.column(
        spacing: 8,
        controls: [
          page.text(value: title, size: 16, weight: "w600"),
          page.text(value: subtitle, size: 12, color: "#6b6f76"),
          page.column(spacing: 8, controls: items)
        ]
      )
    )
  end

  def color_chip(page, color, label)
    page.container(
      width: 44,
      height: 44,
      bgcolor: color,
      border_radius: 10,
      alignment: "center",
      content: page.text(value: label, color: "#ffffff", size: 14)
    )
  end

  def drag_row(page, status)
    page.row(
      spacing: 12,
      controls: [
        page.draggable(
          data: "chip",
          content: page.container(
            padding: 10,
            bgcolor: "#fff4e6",
            border_radius: 10,
            content: page.text(value: "Drag me", size: 14)
          )
        ),
        page.drag_target(
          on_accept: ->(e) { set_status(page, status, "Dropped: #{e.data}") },
          content: page.container(
            padding: 10,
            bgcolor: "#f1f3f5",
            border_radius: 10,
            content: page.text(value: "Drop here", size: 14)
          )
        )
      ]
    )
  end

  def set_status(page, status, value)
    page.update(status, value: value)
  end

  def build_snack_bar(page, status)
    page.snack_bar(
      open: true,
      content: page.text(value: "Saved"),
      action: "UNDO",
      on_action: ->(_e) { set_status(page, status, "SnackBar action") },
      on_dismiss: ->(_e) { set_status(page, status, "SnackBar dismissed") }
    )
  end

  def build_dialog(page, status)
    dialog = nil
    dialog = page.alert_dialog(
      open: false,
      modal: true,
      title: page.text(value: "Delete draft?"),
      content: page.text(value: "This is a sample dialog."),
      actions: [
        page.text_button(
          text: "Cancel",
          on_click: ->(_e) {
            page.update(dialog, open: false)
            set_status(page, status, "Dialog canceled")
          }
        ),
        page.filled_button(
          text: "Delete",
          on_click: ->(_e) {
            page.update(dialog, open: false)
            set_status(page, status, "Delete pressed")
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
        height: 240,
        padding: 16,
        content: page.column(
          spacing: 10,
          controls: [
            page.text(value: "Bottom Sheet", size: 20),
            page.text(value: "Short content to show sizing."),
            page.button(
              text: "Close",
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

StudioGalleryApp.new.run
