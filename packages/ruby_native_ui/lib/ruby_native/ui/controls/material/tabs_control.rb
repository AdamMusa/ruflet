# frozen_string_literal: true

require_relative "column_control"
require_relative "tab_control"
require_relative "tab_bar_control"
require_relative "tab_bar_view_control"

module RubyNative
  module UI
    module Controls
      class TabsControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "tabs", id: id, **props)
        end

        private

        # Normalize shorthand tabs payload into Flet's expected structure:
        # Tabs(length, content: Column(TabBar, TabBarView))
        def preprocess_props(props)
          mapped = props.dup
          tabs = mapped.delete(:tabs) || mapped.delete("tabs")
          return mapped if tabs.nil?
          return mapped unless tabs.is_a?(Array)
          return mapped if mapped.key?(:content) || mapped.key?("content")

          tab_controls = []
          view_controls = []

          tabs.each do |tab|
            unless tab.is_a?(RubyNative::Control) && tab.type == "tab"
              # Non-tab controls are still rendered as tab headers.
              tab_controls << tab
              next
            end

            label = tab.props["label"]
            icon = tab.props["icon"]
            header_tab = RubyNative::UI::Controls::TabControl.new(label: label, icon: icon)
            tab_controls << header_tab

            content = tab.props["content"]
            view_controls << (content.is_a?(RubyNative::Control) ? content : RubyNative::UI::Controls::ColumnControl.new(controls: []))
          end

          tab_bar = RubyNative::UI::Controls::TabBarControl.new(tabs: tab_controls)
          tab_bar_view = RubyNative::UI::Controls::TabBarViewControl.new(expand: 1, controls: view_controls)
          content = RubyNative::UI::Controls::ColumnControl.new(expand: true, spacing: 0, controls: [tab_bar, tab_bar_view])

          mapped[:length] = tab_controls.length unless mapped.key?(:length) || mapped.key?("length")
          # In common page layouts Tabs is placed directly into View controls.
          # Ensure Tabs itself participates in flex so TabBarView receives
          # bounded height constraints.
          unless mapped.key?(:expand) || mapped.key?("expand") || mapped.key?(:height) || mapped.key?("height")
            mapped[:expand] = 1
          end
          mapped[:content] = content
          mapped
        end
      end
    end
  end
end
