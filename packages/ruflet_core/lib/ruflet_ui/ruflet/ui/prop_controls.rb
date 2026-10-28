# frozen_string_literal: true

module Ruflet
  module UI
    # Finds the controls passed as property values: `content:`, `title:`,
    # `actions: [...]`, `children:`/`controls:`, and controls nested anywhere
    # inside Hash and Array values. Inside a DSL block every helper attaches
    # the control it builds to the enclosing builder, so a control created as
    # an argument (`list_tile(title: text("T"))`) is attached before the
    # control that consumes it. Builders use this to take such controls back,
    # so each one ends up only where it was passed.
    #
    # The walk stops at controls: a control's own props were handled when it
    # was built.
    module PropControls
      module_function

      def each_control(value, &block)
        if value.is_a?(Ruflet::Control)
          yield value
        elsif value.is_a?(Hash)
          value.each_value { |item| each_control(item, &block) }
        elsif value.is_a?(Array)
          value.each { |item| each_control(item, &block) }
        end
      end
    end
  end
end
