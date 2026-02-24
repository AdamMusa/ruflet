# frozen_string_literal: true

require_relative "ui/control_methods"
require_relative "ui/control_factory"

module RubyNative
  module DSL
    module_function

    def _pending_app
      @_pending_app ||= App.new(host: "0.0.0.0", port: 8550)
    end

    def _reset_pending_app!
      @_pending_app = App.new(host: "0.0.0.0", port: 8550)
    end

    def app(host: "0.0.0.0", port: 8550, &block)
      return App.new(host: host, port: port).tap { |a| a.instance_eval(&block) } if block

      pending = _pending_app
      pending.set_endpoint!(host: host, port: port)
      _reset_pending_app!
      pending
    end

    def page(**props, &block) = _pending_app.page(**props, &block)
    def control(type, **props, &block) = _pending_app.control(type, **props, &block)
    def widget(type, **props, &block) = _pending_app.widget(type, **props, &block)
    def column(**props, &block) = _pending_app.column(**props, &block)
    def center(**props, &block) = _pending_app.center(**props, &block)
    def row(**props, &block) = _pending_app.row(**props, &block)
    def stack(**props, &block) = _pending_app.stack(**props, &block)
    def container(**props, &block) = _pending_app.container(**props, &block)
    def gesture_detector(**props, &block) = _pending_app.gesture_detector(**props, &block)
    def gesturedetector(**props, &block) = _pending_app.gesturedetector(**props, &block)
    def draggable(**props, &block) = _pending_app.draggable(**props, &block)
    def drag_target(**props, &block) = _pending_app.drag_target(**props, &block)
    def dragtarget(**props, &block) = _pending_app.dragtarget(**props, &block)
    def text(value = nil, **props) = _pending_app.text(value, **props)
    def button(**props) = _pending_app.button(**props)
    def elevated_button(**props) = _pending_app.elevated_button(**props)
    def elevatedbutton(**props) = _pending_app.elevatedbutton(**props)
    def text_field(**props) = _pending_app.text_field(**props)
    def textfield(**props) = _pending_app.textfield(**props)
    def icon(**props) = _pending_app.icon(**props)
    def image(src = nil, **props) = _pending_app.image(src, **props)
    def icon_button(**props) = _pending_app.icon_button(**props)
    def iconbutton(**props) = _pending_app.iconbutton(**props)
    def app_bar(**props) = _pending_app.app_bar(**props)
    def appbar(**props) = _pending_app.appbar(**props)
    def text_button(**props) = _pending_app.text_button(**props)
    def textbutton(**props) = _pending_app.textbutton(**props)
    def filled_button(**props) = _pending_app.filled_button(**props)
    def filledbutton(**props) = _pending_app.filledbutton(**props)
    def checkbox(**props) = _pending_app.checkbox(**props)
    def radio(**props) = _pending_app.radio(**props)
    def radio_group(**props) = _pending_app.radio_group(**props)
    def radiogroup(**props) = _pending_app.radiogroup(**props)
    def alert_dialog(**props) = _pending_app.alert_dialog(**props)
    def alertdialog(**props) = _pending_app.alertdialog(**props)
    def snack_bar(**props) = _pending_app.snack_bar(**props)
    def snackbar(**props) = _pending_app.snackbar(**props)
    def bottom_sheet(**props) = _pending_app.bottom_sheet(**props)
    def bottomsheet(**props) = _pending_app.bottomsheet(**props)
    def markdown(value = nil, **props) = _pending_app.markdown(value, **props)
    def floating_action_button(**props) = _pending_app.floating_action_button(**props)
    def floatingactionbutton(**props) = _pending_app.floatingactionbutton(**props)
    def tabs(**props, &block) = _pending_app.tabs(**props, &block)
    def tab(**props, &block) = _pending_app.tab(**props, &block)
    def tab_bar(**props, &block) = _pending_app.tab_bar(**props, &block)
    def tabbar(**props, &block) = _pending_app.tabbar(**props, &block)
    def tab_bar_view(**props, &block) = _pending_app.tab_bar_view(**props, &block)
    def tabbarview(**props, &block) = _pending_app.tabbarview(**props, &block)
    def navigation_bar(**props, &block) = _pending_app.navigation_bar(**props, &block)
    def navigationbar(**props, &block) = _pending_app.navigationbar(**props, &block)
    def navigation_bar_destination(**props, &block) = _pending_app.navigation_bar_destination(**props, &block)
    def navigationbardestination(**props, &block) = _pending_app.navigationbardestination(**props, &block)
    def fab(content = nil, **props) = _pending_app.fab(content, **props)
    def cupertino_button(**props) = _pending_app.cupertino_button(**props)
    def cupertinobutton(**props) = _pending_app.cupertinobutton(**props)
    def cupertino_filled_button(**props) = _pending_app.cupertino_filled_button(**props)
    def cupertinofilledbutton(**props) = _pending_app.cupertinofilledbutton(**props)
    def cupertino_text_field(**props) = _pending_app.cupertino_text_field(**props)
    def cupertinotextfield(**props) = _pending_app.cupertinotextfield(**props)
    def cupertino_switch(**props) = _pending_app.cupertino_switch(**props)
    def cupertinoswitch(**props) = _pending_app.cupertinoswitch(**props)
    def cupertino_slider(**props) = _pending_app.cupertino_slider(**props)
    def cupertinoslider(**props) = _pending_app.cupertinoslider(**props)
    def cupertino_alert_dialog(**props) = _pending_app.cupertino_alert_dialog(**props)
    def cupertinoalertdialog(**props) = _pending_app.cupertinoalertdialog(**props)
    def cupertino_action_sheet(**props) = _pending_app.cupertino_action_sheet(**props)
    def cupertinoactionsheet(**props) = _pending_app.cupertinoactionsheet(**props)
    def cupertino_dialog_action(**props) = _pending_app.cupertino_dialog_action(**props)
    def cupertinodialogaction(**props) = _pending_app.cupertinodialogaction(**props)
    def cupertino_navigation_bar(**props) = _pending_app.cupertino_navigation_bar(**props)
    def cupertinonavigationbar(**props) = _pending_app.cupertinonavigationbar(**props)

    class App
      include UI::ControlMethods

      attr_reader :page_props, :host, :port

      def initialize(host:, port:)
        @host = host
        @port = port
        @roots = []
        @stack = []
        @page_props = { "route" => "/" }
        @seq = 0
      end

      def set_endpoint!(host:, port:)
        @host = host
        @port = port
      end

      def page(**props, &block)
        @page_props.merge!(normalize_props(props))
        instance_eval(&block) if block
        self
      end

      def widget(type, **props, &block)
        control(type.to_s, **props, &block)
      end

      def control(type, **props, &block)
        mapped_props = props.dup
        prop_children = mapped_props.delete(:controls) || mapped_props.delete("controls")

        id = mapped_props.delete(:id)&.to_s || next_id(type)
        c = RubyNative::UI::ControlFactory.build(type.to_s, id: id, **normalize_props(mapped_props))
        attach(c)

        if block
          @stack.push(c)
          instance_eval(&block)
          @stack.pop
        end

        if prop_children
          Array(prop_children).each { |child| c.children << child if child.is_a?(RubyNative::Control) }
        end

        c
      end

      def run
        app_roots = @roots
        page_props = @page_props.dup

        RubyNative::Server.new(host: host, port: port) do |runtime_page|
          runtime_page.set_view_props(page_props)
          runtime_page.add(*app_roots)
        end.start
      end

      private

      def build_widget(type, **props, &block) = control(type.to_s, **props, &block)

      def attach(control)
        if @stack.empty?
          @roots << control
        else
          @stack.last.children << control
        end
      end

      def normalize_props(hash)
        hash.transform_keys(&:to_s).transform_values { |v| v.is_a?(Symbol) ? v.to_s : v }
      end

      def next_id(type)
        @seq += 1
        "#{type}_#{@seq}"
      end

    end
  end
end
