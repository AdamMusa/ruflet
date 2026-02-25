# frozen_string_literal: true

require_relative "control_methods"
require_relative "control_factory"

module Ruflet
  class WidgetBuilder
    include UI::ControlMethods

    attr_reader :children

    def initialize
      @children = []
    end

    def widget(type, **props, &block)
      control(type, **props, &block)
    end

    def control(type, **props, &block)
      mapped_props = props.dup
      prop_children = mapped_props.delete(:controls) || mapped_props.delete("controls")

      node = UI::ControlFactory.build(type, **mapped_props)
      if block
        nested = WidgetBuilder.new
        block_result = nested.instance_eval(&block)
        if block_result.is_a?(Control) && !nested.children.any? { |c| c.object_id == block_result.object_id }
          nested.children << block_result
        end
        node.children.concat(nested.children)
      end

      if prop_children
        Array(prop_children).each do |child|
          node.children << child if child.is_a?(Control)
        end
      end

      @children << node
      node
    end

    def build_widget(type, **props, &block) = control(type, **props, &block)

    private
  end
end
