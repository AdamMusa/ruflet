# ruflet_ui

UI layer for Ruflet.

## Structure

- `lib/ruflet/control.rb`: core `Control` model and event binding
- `lib/ruflet/ui/control_registry.rb`: control type + event registry
- `lib/ruflet/ui/control_factory.rb`: explicit control class factory (no generic fallback)
- `lib/ruflet/ui/control_methods.rb`: shared explicit DSL/control helper methods
- `lib/ruflet/ui/controls/*.rb`: one class per control, per-control property normalization
- `lib/ruflet/ui/widget_builder.rb`: widget composition + child wiring
- `lib/ruflet/page.rb`: runtime page abstraction
- `lib/ruflet/dsl.rb`: DSL + app builder

## Explicit controls

- Layout: `column`, `row`, `stack`, `container`, `center`
- Inputs: `text_field`, `checkbox`, `radio`, `radio_group`
- Buttons: `button`, `elevated_button`, `text_button`, `filled_button`, `icon_button`, `floating_action_button`
- Display: `text`, `icon`, `image`, `markdown`
- Dialogs/App shell: `alert_dialog`, `app_bar`
- Interaction: `gesture_detector`, `draggable`, `drag_target`

Unsupported control types now raise an explicit error until implemented as a dedicated control class.
