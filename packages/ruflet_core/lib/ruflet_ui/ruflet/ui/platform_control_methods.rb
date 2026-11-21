# frozen_string_literal: true

module Ruflet
  module UI
    # Canonical DSL entry points for controls whose renderer is selected by
    # the Flet client. There is no design-system choice in this API.
    module PlatformControlMethods
      def context_menu_action(content = nil, **props, &block)
        ignore_block("context_menu_action", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:contextmenuaction, **mapped)
      end
      def contextmenuaction(content = nil, **props, &block) = context_menu_action(content, **props, &block)

      def action_sheet(**props, &block) = build_with_block_slot(:actionsheet, "action_sheet", :actions, props.dup, block)
      def actionsheet(**props, &block) = action_sheet(**props, &block)

      def action_sheet_action(content = nil, **props, &block)
        ignore_block("action_sheet_action", block)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:actionsheetaction, **mapped)
      end
      def actionsheetaction(content = nil, **props, &block) = action_sheet_action(content, **props, &block)

      def picker(children = nil, **props, &block)
        mapped = props.dup
        mapped[:controls] = children unless children.nil?
        build_widget(:picker, **mapped, &block)
      end

      def timer_picker(**props) = build_widget(:timerpicker, **props)
      def timerpicker(**props) = timer_picker(**props)
    end
  end
end
