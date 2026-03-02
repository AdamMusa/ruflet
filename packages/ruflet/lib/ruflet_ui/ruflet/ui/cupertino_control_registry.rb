# frozen_string_literal: true

module Ruflet
  module UI
    module CupertinoControlRegistry
      TYPE_MAP = {
        "cupertino_button" => "CupertinoButton",
        "cupertinobutton" => "CupertinoButton",
        "cupertino_filled_button" => "CupertinoFilledButton",
        "cupertinofilledbutton" => "CupertinoFilledButton",
        "cupertino_tinted_button" => "CupertinoTintedButton",
        "cupertinotintedbutton" => "CupertinoTintedButton",
        "cupertino_text_field" => "CupertinoTextField",
        "cupertinotextfield" => "CupertinoTextField",
        "cupertino_checkbox" => "CupertinoCheckbox",
        "cupertinocheckbox" => "CupertinoCheckbox",
        "cupertino_switch" => "CupertinoSwitch",
        "cupertinoswitch" => "CupertinoSwitch",
        "cupertino_slider" => "CupertinoSlider",
        "cupertinoslider" => "CupertinoSlider",
        "cupertino_radio" => "CupertinoRadio",
        "cupertinoradio" => "CupertinoRadio",
        "cupertino_alert_dialog" => "CupertinoAlertDialog",
        "cupertinoalertdialog" => "CupertinoAlertDialog",
        "cupertino_action_sheet" => "CupertinoActionSheet",
        "cupertinoactionsheet" => "CupertinoActionSheet",
        "cupertino_dialog_action" => "CupertinoDialogAction",
        "cupertinodialogaction" => "CupertinoDialogAction",
        "cupertino_bottom_sheet" => "CupertinoBottomSheet",
        "cupertinobottomsheet" => "CupertinoBottomSheet",
        "cupertino_picker" => "CupertinoPicker",
        "cupertinopicker" => "CupertinoPicker",
        "cupertino_date_picker" => "CupertinoDatePicker",
        "cupertinodatepicker" => "CupertinoDatePicker",
        "cupertino_timer_picker" => "CupertinoTimerPicker",
        "cupertinotimerpicker" => "CupertinoTimerPicker",
        "cupertino_navigation_bar" => "CupertinoNavigationBar",
        "cupertinonavigationbar" => "CupertinoNavigationBar"
      }.freeze

      EVENT_PROPS = {
        on_click: "click",
        on_change: "change",
        on_submit: "submit",
        on_dismiss: "dismiss"
      }.freeze
    end
  end
end
