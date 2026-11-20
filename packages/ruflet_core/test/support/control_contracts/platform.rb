# frozen_string_literal: true

require_relative "../control_contract"

# Contract specs for the platform contracts, whose Material or Cupertino look the client picks (PlatformControlContracts).
# See test/support/control_contract.rb for the options and what they assert.

module ControlContract
  define(
    "platform",
    {
      "action_sheet" => { wire: "ActionSheet", aliases: %w[actionsheet] },
      "action_sheet_action" => { wire: "ActionSheetAction", aliases: %w[actionsheetaction], base: { content: TEXT } },
      "alert_dialog" => { wire: "AlertDialog", aliases: %w[alertdialog] },
      "app_bar" => { wire: "AppBar", aliases: %w[appbar] },
      "bottom_sheet" => { wire: "BottomSheet", aliases: %w[bottomsheet], base: { content: TEXT } },
      "button" => { wire: "Button", aliases: %w[elevated_button elevatedbutton] },
      "checkbox" => { wire: "Checkbox" },
      "context_menu" => { wire: "ContextMenu", aliases: %w[contextmenu], base: { content: TEXT } },
      "context_menu_action" => { wire: "ContextMenuAction", aliases: %w[contextmenuaction], base: { content: TEXT } },
      "date_picker" => { wire: "DatePicker", aliases: %w[datepicker] },
      # dropdown_m2's Material 2 spellings travel as the Dropdown keys both
      # renderers read (DropdownControl::MATERIAL2_RENAMES).
      "dropdown" => { wire: "Dropdown", aliases: %w[dropdown_m2 dropdownm2], wire_keys: { max_menu_height: "menu_height", prefix_icon: "leading_icon", select_icon: "trailing_icon", on_change: "on_select" }, client_events: { on_change: "select" } },
      "filled_button" => { wire: "FilledButton", aliases: %w[filledbutton] },
      "filled_tonal_button" => { wire: "FilledTonalButton", aliases: %w[filledtonalbutton] },
      "list_tile" => { wire: "ListTile", aliases: %w[listtile], base: { title: TEXT } },
      "navigation_bar" => { wire: "NavigationBar", aliases: %w[navigationbar] },
      "outlined_button" => { wire: "OutlinedButton", aliases: %w[outlinedbutton] },
      "picker" => { wire: "Picker" },
      "progress_ring" => { wire: "ProgressRing", aliases: %w[progressring] },
      "radio" => { wire: "Radio" },
      "segmented_button" => { wire: "SegmentedButton", aliases: %w[segmentedbutton] },
      "slider" => { wire: "Slider" },
      "switch" => { wire: "Switch" },
      "text_button" => { wire: "TextButton", aliases: %w[textbutton] },
      "text_field" => { wire: "TextField", aliases: %w[textfield] },
      "timer_picker" => { wire: "TimerPicker", aliases: %w[timerpicker] }
    }
  )
end
