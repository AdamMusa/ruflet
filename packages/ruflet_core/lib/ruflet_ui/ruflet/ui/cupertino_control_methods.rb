# frozen_string_literal: true

module Ruflet
  module UI
    module CupertinoControlMethods
      def cupertino_button(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:cupertino_button, **mapped)
      end
      def cupertinobutton(content = nil, **props) = cupertino_button(content, **props)
      def cupertino_filled_button(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:cupertino_filled_button, **mapped)
      end
      def cupertinofilledbutton(content = nil, **props) = cupertino_filled_button(content, **props)
      def cupertino_tinted_button(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:cupertino_tinted_button, **mapped)
      end
      def cupertinotintedbutton(content = nil, **props) = cupertino_tinted_button(content, **props)
      def cupertino_checkbox(**props) = build_widget(:cupertino_checkbox, **props)
      def cupertinocheckbox(**props) = cupertino_checkbox(**props)
      def cupertino_text_field(value = nil, **props)
        mapped = props.dup
        mapped[:value] = value unless value.nil?
        build_widget(:cupertino_text_field, **mapped)
      end
      def cupertinotextfield(value = nil, **props) = cupertino_text_field(value, **props)
      def cupertino_timer_picker(**props) = build_widget(:cupertino_timer_picker, **props)
      def cupertinotimerpicker(**props) = cupertino_timer_picker(**props)
      def cupertino_switch(**props) = build_widget(:cupertino_switch, **props)
      def cupertinoswitch(**props) = cupertino_switch(**props)
      def cupertino_slider(**props) = build_widget(:cupertino_slider, **props)
      def cupertinoslider(**props) = cupertino_slider(**props)
      def cupertino_radio(**props) = build_widget(:cupertino_radio, **props)
      def cupertinoradio(**props) = cupertino_radio(**props)
      def cupertino_alert_dialog(**props) = build_widget(:cupertino_alert_dialog, **props)
      def cupertinoalertdialog(**props) = cupertino_alert_dialog(**props)
      def cupertino_action_sheet(**props) = build_widget(:cupertino_action_sheet, **props)
      def cupertinoactionsheet(**props) = cupertino_action_sheet(**props)
      def cupertino_action_sheet_action(**props) = build_widget(:cupertino_action_sheet_action, **props)
      def cupertinoactionsheetaction(**props) = cupertino_action_sheet_action(**props)
      def cupertino_activity_indicator(**props) = build_widget(:cupertino_activity_indicator, **props)
      def cupertinoactivityindicator(**props) = cupertino_activity_indicator(**props)
      def cupertino_bottom_sheet(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:cupertino_bottom_sheet, **mapped)
      end
      def cupertinobottomsheet(content = nil, **props) = cupertino_bottom_sheet(content, **props)
      def cupertino_date_picker(**props) = build_widget(:cupertino_date_picker, **props)
      def cupertinodatepicker(**props) = cupertino_date_picker(**props)
      def cupertino_dialog_action(**props) = build_widget(:cupertino_dialog_action, **props)
      def cupertinodialogaction(**props) = cupertino_dialog_action(**props)
      def cupertino_context_menu(**props) = build_widget(:cupertino_context_menu, **props)
      def cupertinocontextmenu(**props) = cupertino_context_menu(**props)
      def cupertino_context_menu_action(**props) = build_widget(:cupertino_context_menu_action, **props)
      def cupertinocontextmenuaction(**props) = cupertino_context_menu_action(**props)
      def cupertino_list_tile(**props) = build_widget(:cupertino_list_tile, **props)
      def cupertinolisttile(**props) = cupertino_list_tile(**props)
      def cupertino_navigation_bar(**props) = build_widget(:cupertino_navigation_bar, **props)
      def cupertinonavigationbar(**props) = cupertino_navigation_bar(**props)
      def cupertino_picker(children = nil, **props)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_widget(:cupertinopicker, **mapped)
      end
      def cupertinopicker(children = nil, **props) = cupertino_picker(children, **props)
      def cupertino_segmented_button(children = nil, **props)
        mapped = props.dup
        validate_cupertino_segmented_children!("cupertino_segmented_button", children, mapped)
        mapped[:children] = children unless children.nil?
        build_widget(:cupertinosegmentedbutton, **mapped)
      end
      def cupertinosegmentedbutton(children = nil, **props) = cupertino_segmented_button(children, **props)
      def cupertino_sliding_segmented_button(children = nil, **props)
        mapped = props.dup
        validate_cupertino_segmented_children!("cupertino_sliding_segmented_button", children, mapped)
        mapped[:children] = children unless children.nil?
        build_widget(:cupertinoslidingsegmentedbutton, **mapped)
      end
      def cupertinoslidingsegmentedbutton(children = nil, **props) = cupertino_sliding_segmented_button(children, **props)

      private

      def validate_cupertino_segmented_children!(name, positional_children, props)
        children = positional_children || props[:children] || props["children"] || props[:controls] || props["controls"]
        visible_children = Array(children).reject { |child| child.respond_to?(:props) && child.props["visible"] == false }
        raise ArgumentError, "#{name} controls must include at least two visible controls" if visible_children.length < 2

        selected_index = props[:selected_index] || props["selected_index"] || 0
        unless (0...visible_children.length).cover?(selected_index)
          raise IndexError, "#{name} selected_index is out of range"
        end
      end
    end
  end
end
