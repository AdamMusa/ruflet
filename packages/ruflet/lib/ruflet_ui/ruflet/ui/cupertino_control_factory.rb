# frozen_string_literal: true

require_relative "controls/cupertino/cupertino_button_control"
require_relative "controls/cupertino/cupertino_filled_button_control"
require_relative "controls/cupertino/cupertino_text_field_control"
require_relative "controls/cupertino/cupertino_switch_control"
require_relative "controls/cupertino/cupertino_slider_control"
require_relative "controls/cupertino/cupertino_alert_dialog_control"
require_relative "controls/cupertino/cupertino_action_sheet_control"
require_relative "controls/cupertino/cupertino_dialog_action_control"
require_relative "controls/cupertino/cupertino_navigation_bar_control"

module Ruflet
  module UI
    module CupertinoControlFactory
      module_function

      CLASS_MAP = {
        "cupertino_button" => Controls::CupertinoButtonControl,
        "cupertinobutton" => Controls::CupertinoButtonControl,
        "cupertino_filled_button" => Controls::CupertinoFilledButtonControl,
        "cupertinofilledbutton" => Controls::CupertinoFilledButtonControl,
        "cupertino_text_field" => Controls::CupertinoTextFieldControl,
        "cupertinotextfield" => Controls::CupertinoTextFieldControl,
        "cupertino_switch" => Controls::CupertinoSwitchControl,
        "cupertinoswitch" => Controls::CupertinoSwitchControl,
        "cupertino_slider" => Controls::CupertinoSliderControl,
        "cupertinoslider" => Controls::CupertinoSliderControl,
        "cupertino_alert_dialog" => Controls::CupertinoAlertDialogControl,
        "cupertinoalertdialog" => Controls::CupertinoAlertDialogControl,
        "cupertino_action_sheet" => Controls::CupertinoActionSheetControl,
        "cupertinoactionsheet" => Controls::CupertinoActionSheetControl,
        "cupertino_dialog_action" => Controls::CupertinoDialogActionControl,
        "cupertinodialogaction" => Controls::CupertinoDialogActionControl,
        "cupertino_navigation_bar" => Controls::CupertinoNavigationBarControl,
        "cupertinonavigationbar" => Controls::CupertinoNavigationBarControl
      }.freeze
    end
  end
end
