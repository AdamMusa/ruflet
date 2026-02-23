# frozen_string_literal: true

module RubyNative
  module UI
    module SharedControlForwarders
      def control(type, **props, &block) = control_delegate.control(type, **props, &block)
      def widget(type, **props, &block) = control_delegate.widget(type, **props, &block)
      def view(**props, &block) = control_delegate.view(**props, &block)
      def column(**props, &block) = control_delegate.column(**props, &block)
      def center(**props, &block) = control_delegate.center(**props, &block)
      def row(**props, &block) = control_delegate.row(**props, &block)
      def stack(**props, &block) = control_delegate.stack(**props, &block)
      def container(**props, &block) = control_delegate.container(**props, &block)
      def gesture_detector(**props, &block) = control_delegate.gesture_detector(**props, &block)
      def gesturedetector(**props, &block) = control_delegate.gesturedetector(**props, &block)
      def draggable(**props, &block) = control_delegate.draggable(**props, &block)
      def drag_target(**props, &block) = control_delegate.drag_target(**props, &block)
      def dragtarget(**props, &block) = control_delegate.dragtarget(**props, &block)
      def text(value = nil, **props) = control_delegate.text(value, **props)
      def button(**props) = control_delegate.button(**props)
      def elevated_button(**props) = control_delegate.elevated_button(**props)
      def elevatedbutton(**props) = control_delegate.elevatedbutton(**props)
      def text_button(**props) = control_delegate.text_button(**props)
      def textbutton(**props) = control_delegate.textbutton(**props)
      def filled_button(**props) = control_delegate.filled_button(**props)
      def filledbutton(**props) = control_delegate.filledbutton(**props)
      def icon_button(**props) = control_delegate.icon_button(**props)
      def iconbutton(**props) = control_delegate.iconbutton(**props)
      def text_field(**props) = control_delegate.text_field(**props)
      def textfield(**props) = control_delegate.textfield(**props)
      def checkbox(**props) = control_delegate.checkbox(**props)
      def radio(**props) = control_delegate.radio(**props)
      def radio_group(**props) = control_delegate.radio_group(**props)
      def radiogroup(**props) = control_delegate.radiogroup(**props)
      def alert_dialog(**props) = control_delegate.alert_dialog(**props)
      def alertdialog(**props) = control_delegate.alertdialog(**props)
      def markdown(value = nil, **props) = control_delegate.markdown(value, **props)
      def icon(**props) = control_delegate.icon(**props)
      def image(src = nil, **props) = control_delegate.image(src, **props)
      def fab(content = nil, **props) = control_delegate.fab(content, **props)
      def app_bar(**props) = control_delegate.app_bar(**props)
      def appbar(**props) = control_delegate.appbar(**props)
      def floating_action_button(**props) = control_delegate.floating_action_button(**props)
      def floatingactionbutton(**props) = control_delegate.floatingactionbutton(**props)

      private

      def control_delegate
        raise NotImplementedError, "control_delegate must be implemented by the including/extended context"
      end
    end
  end
end
