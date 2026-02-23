# frozen_string_literal: true

module RubyNative
  module UI
    module CupertinoControlRegistry
      TYPE_MAP = {
        "cupertino_button" => "CupertinoButton",
        "cupertinobutton" => "CupertinoButton",
        "cupertino_filled_button" => "CupertinoFilledButton",
        "cupertinofilledbutton" => "CupertinoFilledButton",
        "cupertino_text_field" => "CupertinoTextField",
        "cupertinotextfield" => "CupertinoTextField",
        "cupertino_switch" => "CupertinoSwitch",
        "cupertinoswitch" => "CupertinoSwitch",
        "cupertino_slider" => "CupertinoSlider",
        "cupertinoslider" => "CupertinoSlider",
        "cupertino_alert_dialog" => "CupertinoAlertDialog",
        "cupertinoalertdialog" => "CupertinoAlertDialog",
        "cupertino_action_sheet" => "CupertinoActionSheet",
        "cupertinoactionsheet" => "CupertinoActionSheet",
        "cupertino_dialog_action" => "CupertinoDialogAction",
        "cupertinodialogaction" => "CupertinoDialogAction",
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
