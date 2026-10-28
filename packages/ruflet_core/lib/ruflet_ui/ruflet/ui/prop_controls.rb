# frozen_string_literal: true

module Ruflet
  module UI
    # Inside a DSL block every helper attaches the control it builds to the
    # enclosing builder, so a control created as an argument
    # (`list_tile(title: text("T"))`) is attached before the control that
    # consumes it, possibly by an enclosing block
    # (`column { t = text("x"); row { container(content: t) } }`). Builders
    # attach through `attach`, which records the owning list on the control,
    # and call `reclaim` with the props of every control they build, so each
    # control ends up only where it was passed.
    module PropControls
      module_function

      # Appends +control+ to +list+ as an implicit DSL child and remembers the
      # list as its owner. Explicit children (`children:`/`controls:`, a
      # block's return value) are appended directly and are never reclaimed.
      def attach(list, control)
        list << control
        control.dsl_owner = list
        control
      end

      # Takes every control found in +props+ back out of the list that
      # implicitly attached it, whichever builder or enclosing block that was.
      # Matching is by identity.
      def reclaim(props)
        each_control(props) do |control|
          owner = control.dsl_owner
          next unless owner

          control.dsl_owner = nil
          index = owner.rindex { |child| child.equal?(control) }
          owner.delete_at(index) if index
        end
      end

      # Yields the controls passed as property values: `content:`, `title:`,
      # `actions: [...]`, `children:`/`controls:`, and controls nested anywhere
      # inside Hash and Array values. The walk stops at controls: a control's
      # own props were handled when it was built.

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
