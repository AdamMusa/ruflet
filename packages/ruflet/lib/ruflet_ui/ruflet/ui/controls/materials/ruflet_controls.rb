# frozen_string_literal: true

require_relative "alertdialog_control"
require_relative "appbar_control"
require_relative "autocomplete_control"
require_relative "badge_control"
require_relative "banner_control"
require_relative "bottomappbar_control"
require_relative "bottomsheet_control"
require_relative "button_control"
require_relative "card_control"
require_relative "checkbox_control"
require_relative "chip_control"
require_relative "circleavatar_control"
require_relative "container_control"
require_relative "contextmenu_control"
require_relative "datacell_control"
require_relative "datacolumn_control"
require_relative "datarow_control"
require_relative "datatable_control"
require_relative "datepicker_control"
require_relative "daterangepicker_control"
require_relative "divider_control"
require_relative "dropdown_control"
require_relative "dropdownm2_control"
require_relative "dropdownoption_control"
require_relative "expansionpanel_control"
require_relative "expansionpanellist_control"
require_relative "expansiontile_control"
require_relative "filledbutton_control"
require_relative "fillediconbutton_control"
require_relative "filledtonalbutton_control"
require_relative "filledtonaliconbutton_control"
require_relative "floatingactionbutton_control"
require_relative "iconbutton_control"
require_relative "listtile_control"
require_relative "menubar_control"
require_relative "menuitembutton_control"
require_relative "navigationbar_control"
require_relative "navigationbardestination_control"
require_relative "navigationdrawer_control"
require_relative "navigationdrawerdestination_control"
require_relative "navigationrail_control"
require_relative "navigationraildestination_control"
require_relative "option_control"
require_relative "outlinedbutton_control"
require_relative "outlinediconbutton_control"
require_relative "popupmenubutton_control"
require_relative "popupmenuitem_control"
require_relative "progressbar_control"
require_relative "progressring_control"
require_relative "radio_control"
require_relative "radiogroup_control"
require_relative "rangeslider_control"
require_relative "reorderablelistview_control"
require_relative "searchbar_control"
require_relative "segment_control"
require_relative "segmentedbutton_control"
require_relative "selectionarea_control"
require_relative "slider_control"
require_relative "snackbar_control"
require_relative "submenubutton_control"
require_relative "switch_control"
require_relative "tab_control"
require_relative "tabbar_control"
require_relative "tabbarview_control"
require_relative "tabs_control"
require_relative "textbutton_control"
require_relative "textfield_control"
require_relative "timepicker_control"
require_relative "verticaldivider_control"

module Ruflet
  module UI
    module Controls
      module Materials
        module RufletControls
          module_function

          CLASS_MAP = {
            "alert_dialog" => RufletComponents::AlertDialogControl,
            "alertdialog" => RufletComponents::AlertDialogControl,
            "app_bar" => RufletComponents::AppBarControl,
            "appbar" => RufletComponents::AppBarControl,
            "auto_complete" => RufletComponents::AutoCompleteControl,
            "autocomplete" => RufletComponents::AutoCompleteControl,
            "badge" => RufletComponents::BadgeControl,
            "banner" => RufletComponents::BannerControl,
            "bottom_app_bar" => RufletComponents::BottomAppBarControl,
            "bottom_sheet" => RufletComponents::BottomSheetControl,
            "bottomappbar" => RufletComponents::BottomAppBarControl,
            "bottomsheet" => RufletComponents::BottomSheetControl,
            "button" => RufletComponents::ButtonControl,
            "card" => RufletComponents::CardControl,
            "checkbox" => RufletComponents::CheckboxControl,
            "chip" => RufletComponents::ChipControl,
            "circle_avatar" => RufletComponents::CircleAvatarControl,
            "circleavatar" => RufletComponents::CircleAvatarControl,
            "container" => RufletComponents::ContainerControl,
            "context_menu" => RufletComponents::ContextMenuControl,
            "contextmenu" => RufletComponents::ContextMenuControl,
            "data_cell" => RufletComponents::DataCellControl,
            "data_column" => RufletComponents::DataColumnControl,
            "data_row" => RufletComponents::DataRowControl,
            "data_table" => RufletComponents::DataTableControl,
            "datacell" => RufletComponents::DataCellControl,
            "datacolumn" => RufletComponents::DataColumnControl,
            "datarow" => RufletComponents::DataRowControl,
            "datatable" => RufletComponents::DataTableControl,
            "date_picker" => RufletComponents::DatePickerControl,
            "date_range_picker" => RufletComponents::DateRangePickerControl,
            "datepicker" => RufletComponents::DatePickerControl,
            "daterangepicker" => RufletComponents::DateRangePickerControl,
            "divider" => RufletComponents::DividerControl,
            "dropdown" => RufletComponents::DropdownControl,
            "dropdown_m2" => RufletComponents::Dropdown2Control,
            "dropdown_option" => RufletComponents::DropdownOptionControl,
            "dropdownm2" => RufletComponents::Dropdown2Control,
            "dropdownoption" => RufletComponents::DropdownOptionControl,
            "expansion_panel" => RufletComponents::ExpansionPanelControl,
            "expansion_panel_list" => RufletComponents::ExpansionPanelListControl,
            "expansion_tile" => RufletComponents::ExpansionTileControl,
            "expansionpanel" => RufletComponents::ExpansionPanelControl,
            "expansionpanellist" => RufletComponents::ExpansionPanelListControl,
            "expansiontile" => RufletComponents::ExpansionTileControl,
            "filled_button" => RufletComponents::FilledButtonControl,
            "filled_icon_button" => RufletComponents::FilledIconButtonControl,
            "filled_tonal_button" => RufletComponents::FilledTonalButtonControl,
            "filled_tonal_icon_button" => RufletComponents::FilledTonalIconButtonControl,
            "filledbutton" => RufletComponents::FilledButtonControl,
            "fillediconbutton" => RufletComponents::FilledIconButtonControl,
            "filledtonalbutton" => RufletComponents::FilledTonalButtonControl,
            "filledtonaliconbutton" => RufletComponents::FilledTonalIconButtonControl,
            "floating_action_button" => RufletComponents::FloatingActionButtonControl,
            "floatingactionbutton" => RufletComponents::FloatingActionButtonControl,
            "icon_button" => RufletComponents::IconButtonControl,
            "iconbutton" => RufletComponents::IconButtonControl,
            "list_tile" => RufletComponents::ListTileControl,
            "listtile" => RufletComponents::ListTileControl,
            "menu_bar" => RufletComponents::MenuBarControl,
            "menu_item_button" => RufletComponents::MenuItemButtonControl,
            "menubar" => RufletComponents::MenuBarControl,
            "menuitembutton" => RufletComponents::MenuItemButtonControl,
            "navigation_bar" => RufletComponents::NavigationBarControl,
            "navigation_bar_destination" => RufletComponents::NavigationBarDestinationControl,
            "navigation_drawer" => RufletComponents::NavigationDrawerControl,
            "navigation_drawer_destination" => RufletComponents::NavigationDrawerDestinationControl,
            "navigation_rail" => RufletComponents::NavigationRailControl,
            "navigation_rail_destination" => RufletComponents::NavigationRailDestinationControl,
            "navigationbar" => RufletComponents::NavigationBarControl,
            "navigationbardestination" => RufletComponents::NavigationBarDestinationControl,
            "navigationdrawer" => RufletComponents::NavigationDrawerControl,
            "navigationdrawerdestination" => RufletComponents::NavigationDrawerDestinationControl,
            "navigationrail" => RufletComponents::NavigationRailControl,
            "navigationraildestination" => RufletComponents::NavigationRailDestinationControl,
            "option" => RufletComponents::OptionControl,
            "outlined_button" => RufletComponents::OutlinedButtonControl,
            "outlined_icon_button" => RufletComponents::OutlinedIconButtonControl,
            "outlinedbutton" => RufletComponents::OutlinedButtonControl,
            "outlinediconbutton" => RufletComponents::OutlinedIconButtonControl,
            "popup_menu_button" => RufletComponents::PopupMenuButtonControl,
            "popup_menu_item" => RufletComponents::PopupMenuItemControl,
            "popupmenubutton" => RufletComponents::PopupMenuButtonControl,
            "popupmenuitem" => RufletComponents::PopupMenuItemControl,
            "progress_bar" => RufletComponents::ProgressBarControl,
            "progress_ring" => RufletComponents::ProgressRingControl,
            "progressbar" => RufletComponents::ProgressBarControl,
            "progressring" => RufletComponents::ProgressRingControl,
            "radio" => RufletComponents::RadioControl,
            "radio_group" => RufletComponents::RadioGroupControl,
            "radiogroup" => RufletComponents::RadioGroupControl,
            "range_slider" => RufletComponents::RangeSliderControl,
            "rangeslider" => RufletComponents::RangeSliderControl,
            "reorderable_list_view" => RufletComponents::ReorderableListViewControl,
            "reorderablelistview" => RufletComponents::ReorderableListViewControl,
            "search_bar" => RufletComponents::SearchBarControl,
            "searchbar" => RufletComponents::SearchBarControl,
            "segment" => RufletComponents::SegmentControl,
            "segmented_button" => RufletComponents::SegmentedButtonControl,
            "segmentedbutton" => RufletComponents::SegmentedButtonControl,
            "selection_area" => RufletComponents::SelectionAreaControl,
            "selectionarea" => RufletComponents::SelectionAreaControl,
            "slider" => RufletComponents::SliderControl,
            "snack_bar" => RufletComponents::SnackBarControl,
            "snackbar" => RufletComponents::SnackBarControl,
            "submenu_button" => RufletComponents::SubmenuButtonControl,
            "submenubutton" => RufletComponents::SubmenuButtonControl,
            "switch" => RufletComponents::SwitchControl,
            "tab" => RufletComponents::TabControl,
            "tab_bar" => RufletComponents::TabBarControl,
            "tab_bar_view" => RufletComponents::TabBarViewControl,
            "tabbar" => RufletComponents::TabBarControl,
            "tabbarview" => RufletComponents::TabBarViewControl,
            "tabs" => RufletComponents::TabsControl,
            "text_button" => RufletComponents::TextButtonControl,
            "text_field" => RufletComponents::TextFieldControl,
            "textbutton" => RufletComponents::TextButtonControl,
            "textfield" => RufletComponents::TextFieldControl,
            "time_picker" => RufletComponents::TimePickerControl,
            "timepicker" => RufletComponents::TimePickerControl,
            "vertical_divider" => RufletComponents::VerticalDividerControl,
            "verticaldivider" => RufletComponents::VerticalDividerControl,
          }.freeze
        end
      end
    end
  end
end
