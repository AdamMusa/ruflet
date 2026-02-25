# frozen_string_literal: true

module Ruflet
  module UI
    module MaterialControlMethods
      def view(**props, &block) = build_widget(:view, **props, &block)
      def column(**props, &block) = build_widget(:column, **props, &block)

      def center(**props, &block)
        mapped = props.dup
        defaults = { expand: true, alignment: { x: 0, y: 0 } }

        if block
          nested = WidgetBuilder.new
          block_result = nested.instance_eval(&block)
          child =
            if nested.children.any?
              nested.children.first
            elsif block_result.is_a?(Ruflet::Control)
              block_result
            end
          mapped[:content] = child if child
        end

        build_widget(:container, **normalize_container_props(defaults.merge(mapped)))
      end

      def row(**props, &block) = build_widget(:row, **props, &block)
      def stack(**props, &block) = build_widget(:stack, **props, &block)
      def container(**props, &block) = build_widget(:container, **normalize_container_props(props), &block)
      def gesture_detector(**props, &block) = build_widget(:gesturedetector, **props, &block)
      def gesturedetector(**props, &block) = gesture_detector(**props, &block)
      def draggable(**props, &block) = build_widget(:draggable, **props, &block)
      def drag_target(**props, &block) = build_widget(:dragtarget, **props, &block)
      def dragtarget(**props, &block) = drag_target(**props, &block)

      def text(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:text, **mapped)
      end

      def button(**props) = build_widget(:button, **props)
      def elevated_button(**props) = build_widget(:elevatedbutton, **props)
      def elevatedbutton(**props) = elevated_button(**props)
      def text_button(**props) = build_widget(:textbutton, **props)
      def textbutton(**props) = text_button(**props)
      def filled_button(**props) = build_widget(:filledbutton, **props)
      def filledbutton(**props) = filled_button(**props)

      def icon_button(**props) = build_widget(:iconbutton, **props)
      def iconbutton(**props) = icon_button(**props)
      def text_field(**props) = build_widget(:textfield, **props)
      def textfield(**props) = text_field(**props)
      def checkbox(**props) = build_widget(:checkbox, **props)
      def radio(**props) = build_widget(:radio, **props)
      def radio_group(**props) = build_widget(:radiogroup, **props)
      def radiogroup(**props) = radio_group(**props)
      def alert_dialog(**props) = build_widget(:alertdialog, **props)
      def alertdialog(**props) = alert_dialog(**props)
      def snack_bar(**props) = build_widget(:snackbar, **props)
      def snackbar(**props) = snack_bar(**props)
      def bottom_sheet(**props) = build_widget(:bottomsheet, **props)
      def bottomsheet(**props) = bottom_sheet(**props)

      def markdown(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:markdown, **mapped)
      end

      def icon(**props) = build_widget(:icon, **props)

      def image(src = nil, **props)
        mapped = props.dup
        mapped[:src] = src unless src.nil?
        build_widget(:image, **mapped)
      end

      def app_bar(**props) = build_widget(:appbar, **props)
      def appbar(**props) = app_bar(**props)
      def floating_action_button(**props) = build_widget(:floatingactionbutton, **props)
      def floatingactionbutton(**props) = floating_action_button(**props)
      def tabs(**props, &block) = build_widget(:tabs, **props, &block)
      def tab(**props, &block) = build_widget(:tab, **props, &block)
      def tab_bar(**props, &block) = build_widget(:tabbar, **props, &block)
      def tabbar(**props, &block) = tab_bar(**props, &block)
      def tab_bar_view(**props, &block) = build_widget(:tabbarview, **props, &block)
      def tabbarview(**props, &block) = tab_bar_view(**props, &block)
      def navigation_bar(**props, &block) = build_widget(:navigationbar, **props, &block)
      def navigationbar(**props, &block) = navigation_bar(**props, &block)
      def navigation_bar_destination(**props, &block) = build_widget(:navigationbardestination, **props, &block)
      def navigationbardestination(**props, &block) = navigation_bar_destination(**props, &block)

      def fab(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:floatingactionbutton, **mapped)
      end

      private

      # Flet container alignment expects a vector-like object ({x:, y:}),
      # not a plain string. Keep common shorthand compatible.
      def normalize_container_props(props)
        mapped = props.dup
        alignment = mapped[:alignment] || mapped["alignment"]
        if alignment == "center" || alignment == :center
          mapped[:alignment] = { x: 0, y: 0 }
          mapped.delete("alignment")
        end
        mapped
      end
    end
  end
end
