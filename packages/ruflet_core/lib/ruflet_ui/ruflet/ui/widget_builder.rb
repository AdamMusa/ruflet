# frozen_string_literal: true

require_relative "control_methods"
require_relative "control_factory"
require_relative "prop_controls"

module Ruflet
  class WidgetBuilder
    include UI::ControlMethods

    attr_reader :children

    def initialize
      @children = []
      # object_id => true for every control this builder attached itself, so
      # a control used as a prop is only taken back from the builder that
      # attached it, never from children added explicitly.
      @attached = {}
    end

    def widget(type, **props, &block)
      control(type, **props, &block)
    end

    def service(type, **props, &block)
      build_service(type, **props, &block)
    end

    def control(type, **props, &block)
      mapped_props = props.dup
      prop_children = extract_children_prop(mapped_props)

      node = UI::ControlFactory.build(type, **mapped_props)
      detach_prop_controls(props)
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
      @attached[node.object_id] = true
      node
    end

    def build_widget(type, **props, &block) = control(type, **props, &block)
    def build_service(type, **props, &block)
      mapped_props = props.dup
      node = UI::ControlFactory.build(type, **mapped_props)
      detach_prop_controls(props)
      node
    end

    private

    # A control passed as a prop was attached here when its helper ran, which
    # was before the control consuming it was built. Take it back so it is not
    # also a sibling of that control. It is usually the most recent child, so
    # search from the end.
    def detach_prop_controls(props)
      return if @attached.empty?

      UI::PropControls.each_control(props) do |control|
        next unless @attached.delete(control.object_id)

        index = @children.rindex { |child| child.equal?(control) }
        @children.delete_at(index) if index
      end
    end

    def extract_children_prop(props)
      props.delete(:children) ||
        props.delete("children") ||
        props.delete(:controls) ||
        props.delete("controls")
    end
  end
end
