# frozen_string_literal: true

require_relative "../control_contract"

# Contract specs for the Cupertino controls (lib/ruflet_ui/ruflet/ui/controls/cupertinos).
# See test/support/control_contract.rb for the options and what they assert.

module ControlContract
  define(
    "cupertino",
    {
      "cupertino_action_sheet" => { wire: "ActionSheet", aliases: %w[cupertinoactionsheet] },
      "cupertino_action_sheet_action" => { wire: "ActionSheetAction", aliases: %w[cupertinoactionsheetaction], base: { content: TEXT } },
      "cupertino_activity_indicator" => { wire: "ProgressRing", aliases: %w[cupertinoactivityindicator] },
      "cupertino_alert_dialog" => { wire: "AlertDialog", aliases: %w[cupertinoalertdialog] },
      "cupertino_app_bar" => { wire: "AppBar", aliases: %w[cupertinoappbar] },
      "cupertino_bottom_sheet" => { wire: "BottomSheet", aliases: %w[cupertinobottomsheet], base: { content: TEXT } },
      "cupertino_button" => { wire: "Button", aliases: %w[cupertinobutton] },
      "cupertino_checkbox" => { wire: "Checkbox", aliases: %w[cupertinocheckbox] },
      "cupertino_context_menu" => { wire: "ContextMenu", aliases: %w[cupertinocontextmenu], base: { content: TEXT } },
      "cupertino_context_menu_action" => { wire: "ContextMenuAction", aliases: %w[cupertinocontextmenuaction], base: { content: TEXT } },
      "cupertino_date_picker" => { wire: "DatePicker", aliases: %w[cupertinodatepicker] },
      "cupertino_dialog_action" => { wire: "Button", aliases: %w[cupertinodialogaction], base: { content: TEXT } },
      "cupertino_filled_button" => { wire: "FilledButton", aliases: %w[cupertinofilledbutton] },
      "cupertino_list_tile" => { wire: "ListTile", aliases: %w[cupertinolisttile], base: { title: TEXT } },
      "cupertino_navigation_bar" => { wire: "NavigationBar", aliases: %w[cupertinonavigationbar] },
      "cupertino_picker" => { wire: "Picker", aliases: %w[cupertinopicker] },
      "cupertino_radio" => { wire: "Radio", aliases: %w[cupertinoradio] },
      "cupertino_segmented_button" => { wire: "SegmentedButton", aliases: %w[cupertinosegmentedbutton], helper_props: { controls: TWO_TEXTS } },
      "cupertino_slider" => { wire: "Slider", aliases: %w[cupertinoslider] },
      "cupertino_sliding_segmented_button" => { wire: "SegmentedButton", aliases: %w[cupertinoslidingsegmentedbutton], helper_props: { controls: TWO_TEXTS } },
      # The thumb images are sent under the *_src keys the renderer reads.
      "cupertino_switch" => { wire: "Switch", aliases: %w[cupertinoswitch], wire_keys: { active_thumb_image: "active_thumb_image_src", inactive_thumb_image: "inactive_thumb_image_src" } },
      "cupertino_text_field" => { wire: "TextField", aliases: %w[cupertinotextfield] },
      "cupertino_timer_picker" => { wire: "TimerPicker", aliases: %w[cupertinotimerpicker] },
      "cupertino_tinted_button" => { wire: "FilledTonalButton", aliases: %w[cupertinotintedbutton] }
    }
  )
end
