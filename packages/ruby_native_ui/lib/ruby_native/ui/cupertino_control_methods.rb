# frozen_string_literal: true

module RubyNative
  module UI
    module CupertinoControlMethods
      def cupertino_button(**props) = build_widget(:cupertino_button, **props)
      def cupertinobutton(**props) = cupertino_button(**props)
      def cupertino_filled_button(**props) = build_widget(:cupertino_filled_button, **props)
      def cupertinofilledbutton(**props) = cupertino_filled_button(**props)
      def cupertino_text_field(**props) = build_widget(:cupertino_text_field, **props)
      def cupertinotextfield(**props) = cupertino_text_field(**props)
      def cupertino_switch(**props) = build_widget(:cupertino_switch, **props)
      def cupertinoswitch(**props) = cupertino_switch(**props)
      def cupertino_slider(**props) = build_widget(:cupertino_slider, **props)
      def cupertinoslider(**props) = cupertino_slider(**props)
      def cupertino_alert_dialog(**props) = build_widget(:cupertino_alert_dialog, **props)
      def cupertinoalertdialog(**props) = cupertino_alert_dialog(**props)
      def cupertino_action_sheet(**props) = build_widget(:cupertino_action_sheet, **props)
      def cupertinoactionsheet(**props) = cupertino_action_sheet(**props)
      def cupertino_dialog_action(**props) = build_widget(:cupertino_dialog_action, **props)
      def cupertinodialogaction(**props) = cupertino_dialog_action(**props)
      def cupertino_navigation_bar(**props) = build_widget(:cupertino_navigation_bar, **props)
      def cupertinonavigationbar(**props) = cupertino_navigation_bar(**props)
    end
  end
end
