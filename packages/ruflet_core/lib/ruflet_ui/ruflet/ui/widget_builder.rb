# frozen_string_literal: true

require_relative "control_methods"
require_relative "control_factory"
require_relative "prop_controls"
require_relative "build_scope"
require_relative "service_types"

module Ruflet
  class WidgetBuilder
    include UI::ControlMethods

    attr_reader :children, :services

    # +services+ is where engine services built in the block go (Page#mount
    # passes one and adds them to the page). Without it they are returned to
    # the caller and placed nowhere, like every service a builder builds.
    def initialize(services: nil)
      @children = []
      @services = services
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
      UI::PropControls.reclaim(props)
      if block
        nested = WidgetBuilder.new(services: @services)
        block_result = UI::BuildScope.within(nested) { nested.instance_eval(&block) }
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

      return collect_service(node) if UI::ServiceTypes.service_wire_type?(node.wire_type)

      UI::PropControls.attach(@children, node)
    end

    # Ruflet.duration(...) delegates here; it is milliseconds, not a control.
    def duration(**parts) = DSL.duration(**parts)

    def build_widget(type, **props, &block) = control(type, **props, &block)
    def build_service(type, **props, &block)
      mapped_props = props.dup
      node = UI::ControlFactory.build(type, **mapped_props)
      UI::PropControls.reclaim(props)
      collect_service(node)
    end

    private

    def collect_service(node)
      @services << node if @services && !@services.include?(node)
      node
    end

    def extract_children_prop(props)
      props.delete(:children) ||
        props.delete("children") ||
        props.delete(:controls) ||
        props.delete("controls")
    end
  end
end
