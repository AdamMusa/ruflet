# frozen_string_literal: true

module Ruflet
  module UI
    module CupertinoControlMethods
      # Deprecated compatibility spellings. Platform selection now happens in
      # Flet and every method below forwards to a canonical control entrypoint.
      def cupertino_button(content = nil, **props, &block)
        ignore_block("cupertino_button", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:cupertino_button, **mapped)
      end
      def cupertinobutton(content = nil, **props, &block) = cupertino_button(content, **props, &block)
      def cupertino_filled_button(content = nil, **props, &block)
        ignore_block("cupertino_filled_button", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:cupertino_filled_button, **mapped)
      end
      def cupertinofilledbutton(content = nil, **props, &block) = cupertino_filled_button(content, **props, &block)
      def cupertino_tinted_button(content = nil, **props, &block)
        ignore_block("cupertino_tinted_button", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:cupertino_tinted_button, **mapped)
      end
      def cupertinotintedbutton(content = nil, **props, &block) = cupertino_tinted_button(content, **props, &block)
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
      def cupertino_alert_dialog(**props, &block) = build_with_block_slot(:cupertino_alert_dialog, "cupertino_alert_dialog", :content, props.dup, block)
      def cupertinoalertdialog(**props, &block) = cupertino_alert_dialog(**props, &block)
      def cupertino_action_sheet(**props, &block) = build_with_block_slot(:cupertino_action_sheet, "cupertino_action_sheet", :actions, props.dup, block)
      def cupertinoactionsheet(**props, &block) = cupertino_action_sheet(**props, &block)
      def cupertino_action_sheet_action(**props, &block)
        ignore_block("cupertino_action_sheet_action", block)
        build_widget(:cupertino_action_sheet_action, **props)
      end
      def cupertinoactionsheetaction(**props, &block) = cupertino_action_sheet_action(**props, &block)
      def cupertino_activity_indicator(**props) = build_widget(:cupertino_activity_indicator, **props)
      def cupertinoactivityindicator(**props) = cupertino_activity_indicator(**props)
      def cupertino_app_bar(**props) = build_widget(:cupertino_app_bar, **props)
      def cupertinoappbar(**props) = cupertino_app_bar(**props)
      def cupertino_bottom_sheet(content = nil, **props, &block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_with_block_slot(:cupertino_bottom_sheet, "cupertino_bottom_sheet", :content, mapped, block)
      end
      def cupertinobottomsheet(content = nil, **props, &block) = cupertino_bottom_sheet(content, **props, &block)
      def cupertino_date_picker(**props) = build_widget(:cupertino_date_picker, **props)
      def cupertinodatepicker(**props) = cupertino_date_picker(**props)
      def cupertino_dialog_action(**props, &block)
        ignore_block("cupertino_dialog_action", block)
        build_widget(:cupertino_dialog_action, **props)
      end
      def cupertinodialogaction(**props, &block) = cupertino_dialog_action(**props, &block)
      def cupertino_context_menu(**props, &block) = build_with_block_slot(:cupertino_context_menu, "cupertino_context_menu", :content, props.dup, block)
      def cupertinocontextmenu(**props, &block) = cupertino_context_menu(**props, &block)
      def cupertino_context_menu_action(**props, &block)
        ignore_block("cupertino_context_menu_action", block)
        build_widget(:cupertino_context_menu_action, **props)
      end
      def cupertinocontextmenuaction(**props, &block) = cupertino_context_menu_action(**props, &block)
      def cupertino_list_tile(**props) = build_widget(:cupertino_list_tile, **props)
      def cupertinolisttile(**props) = cupertino_list_tile(**props)
      def cupertino_navigation_bar(**props, &block) = build_with_block_slot(:cupertino_navigation_bar, "cupertino_navigation_bar", :destinations, props.dup, block)
      def cupertinonavigationbar(**props, &block) = cupertino_navigation_bar(**props, &block)
      def cupertino_picker(children = nil, **props, &block)
        mapped = props.dup
        mapped[:children] = children unless children.nil?
        build_with_block_children(:cupertinopicker, "cupertino_picker", mapped, block)
      end
      def cupertinopicker(children = nil, **props, &block) = cupertino_picker(children, **props, &block)
      def cupertino_segmented_button(children = nil, **props, &block)
        mapped = props.dup
        children = segmented_block_children("cupertino_segmented_button", children, mapped, block)
        validate_cupertino_segmented_children!("cupertino_segmented_button", children, mapped)
        mapped[:children] = children unless children.nil?
        build_widget(:cupertinosegmentedbutton, **mapped)
      end
      def cupertinosegmentedbutton(children = nil, **props, &block) = cupertino_segmented_button(children, **props, &block)
      def cupertino_sliding_segmented_button(children = nil, **props, &block)
        mapped = props.dup
        children = segmented_block_children("cupertino_sliding_segmented_button", children, mapped, block)
        validate_cupertino_segmented_children!("cupertino_sliding_segmented_button", children, mapped)
        mapped[:children] = children unless children.nil?
        build_widget(:cupertinoslidingsegmentedbutton, **mapped)
      end
      def cupertinoslidingsegmentedbutton(children = nil, **props, &block) = cupertino_sliding_segmented_button(children, **props, &block)

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
