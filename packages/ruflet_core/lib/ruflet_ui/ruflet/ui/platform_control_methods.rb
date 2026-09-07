# frozen_string_literal: true

module Ruflet
  module UI
    # Canonical DSL entry points for controls whose renderer is selected by
    # the Flet client. There is no design-system choice in this API.
    module PlatformControlMethods
      def context_menu_action(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:contextmenuaction, **mapped)
      end
      def contextmenuaction(content = nil, **props) = context_menu_action(content, **props)

      def action_sheet(**props) = build_widget(:actionsheet, **props)
      def actionsheet(**props) = action_sheet(**props)

      def action_sheet_action(content = nil, **props)
        mapped = props.dup
        mapped[:content] = content unless content.nil?
        build_widget(:actionsheetaction, **mapped)
      end
      def actionsheetaction(content = nil, **props) = action_sheet_action(content, **props)

      def picker(children = nil, **props)
        mapped = props.dup
        mapped[:controls] = children unless children.nil?
        build_widget(:picker, **mapped)
      end

      def timer_picker(**props) = build_widget(:timerpicker, **props)
      def timerpicker(**props) = timer_picker(**props)
    end
  end
end
