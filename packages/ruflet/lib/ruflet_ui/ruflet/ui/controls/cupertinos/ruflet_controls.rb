# frozen_string_literal: true

require_relative "cupertinoactionsheet_control"
require_relative "cupertinoactionsheetaction_control"
require_relative "cupertinoactivityindicator_control"
require_relative "cupertinoalertdialog_control"
require_relative "cupertinoappbar_control"
require_relative "cupertinobottomsheet_control"
require_relative "cupertinobutton_control"
require_relative "cupertinocheckbox_control"
require_relative "cupertinocontextmenu_control"
require_relative "cupertinocontextmenuaction_control"
require_relative "cupertinodatepicker_control"
require_relative "cupertinodialogaction_control"
require_relative "cupertinofilledbutton_control"
require_relative "cupertinolisttile_control"
require_relative "cupertinonavigationbar_control"
require_relative "cupertinopicker_control"
require_relative "cupertinoradio_control"
require_relative "cupertinosegmentedbutton_control"
require_relative "cupertinoslider_control"
require_relative "cupertinoslidingsegmentedbutton_control"
require_relative "cupertinoswitch_control"
require_relative "cupertinotextfield_control"
require_relative "cupertinotimerpicker_control"
require_relative "cupertinotintedbutton_control"

module Ruflet
  module UI
    module Controls
      module Cupertinos
        module RufletControls
          module_function

          CLASS_MAP = {
            "cupertino_action_sheet" => RufletComponents::CupertinoActionSheetControl,
            "cupertino_action_sheet_action" => RufletComponents::CupertinoActionSheetActionControl,
            "cupertino_activity_indicator" => RufletComponents::CupertinoActivityIndicatorControl,
            "cupertino_alert_dialog" => RufletComponents::CupertinoAlertDialogControl,
            "cupertino_app_bar" => RufletComponents::CupertinoAppBarControl,
            "cupertino_bottom_sheet" => RufletComponents::CupertinoBottomSheetControl,
            "cupertino_button" => RufletComponents::CupertinoButtonControl,
            "cupertino_checkbox" => RufletComponents::CupertinoCheckboxControl,
            "cupertino_context_menu" => RufletComponents::CupertinoContextMenuControl,
            "cupertino_context_menu_action" => RufletComponents::CupertinoContextMenuActionControl,
            "cupertino_date_picker" => RufletComponents::CupertinoDatePickerControl,
            "cupertino_dialog_action" => RufletComponents::CupertinoDialogActionControl,
            "cupertino_filled_button" => RufletComponents::CupertinoFilledButtonControl,
            "cupertino_list_tile" => RufletComponents::CupertinoListTileControl,
            "cupertino_navigation_bar" => RufletComponents::CupertinoNavigationBarControl,
            "cupertino_picker" => RufletComponents::CupertinoPickerControl,
            "cupertino_radio" => RufletComponents::CupertinoRadioControl,
            "cupertino_segmented_button" => RufletComponents::CupertinoSegmentedButtonControl,
            "cupertino_slider" => RufletComponents::CupertinoSliderControl,
            "cupertino_sliding_segmented_button" => RufletComponents::CupertinoSlidingSegmentedButtonControl,
            "cupertino_switch" => RufletComponents::CupertinoSwitchControl,
            "cupertino_text_field" => RufletComponents::CupertinoTextFieldControl,
            "cupertino_timer_picker" => RufletComponents::CupertinoTimerPickerControl,
            "cupertino_tinted_button" => RufletComponents::CupertinoTintedButtonControl,
            "cupertinoactionsheet" => RufletComponents::CupertinoActionSheetControl,
            "cupertinoactionsheetaction" => RufletComponents::CupertinoActionSheetActionControl,
            "cupertinoactivityindicator" => RufletComponents::CupertinoActivityIndicatorControl,
            "cupertinoalertdialog" => RufletComponents::CupertinoAlertDialogControl,
            "cupertinoappbar" => RufletComponents::CupertinoAppBarControl,
            "cupertinobottomsheet" => RufletComponents::CupertinoBottomSheetControl,
            "cupertinobutton" => RufletComponents::CupertinoButtonControl,
            "cupertinocheckbox" => RufletComponents::CupertinoCheckboxControl,
            "cupertinocontextmenu" => RufletComponents::CupertinoContextMenuControl,
            "cupertinocontextmenuaction" => RufletComponents::CupertinoContextMenuActionControl,
            "cupertinodatepicker" => RufletComponents::CupertinoDatePickerControl,
            "cupertinodialogaction" => RufletComponents::CupertinoDialogActionControl,
            "cupertinofilledbutton" => RufletComponents::CupertinoFilledButtonControl,
            "cupertinolisttile" => RufletComponents::CupertinoListTileControl,
            "cupertinonavigationbar" => RufletComponents::CupertinoNavigationBarControl,
            "cupertinopicker" => RufletComponents::CupertinoPickerControl,
            "cupertinoradio" => RufletComponents::CupertinoRadioControl,
            "cupertinosegmentedbutton" => RufletComponents::CupertinoSegmentedButtonControl,
            "cupertinoslider" => RufletComponents::CupertinoSliderControl,
            "cupertinoslidingsegmentedbutton" => RufletComponents::CupertinoSlidingSegmentedButtonControl,
            "cupertinoswitch" => RufletComponents::CupertinoSwitchControl,
            "cupertinotextfield" => RufletComponents::CupertinoTextFieldControl,
            "cupertinotimerpicker" => RufletComponents::CupertinoTimerPickerControl,
            "cupertinotintedbutton" => RufletComponents::CupertinoTintedButtonControl,
          }.freeze
        end
      end
    end
  end
end
