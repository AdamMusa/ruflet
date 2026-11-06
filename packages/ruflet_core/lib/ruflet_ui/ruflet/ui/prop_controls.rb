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
      # data: is the application's own payload (`button(data: { target: t })`):
      # a control referenced from it is never a child of the control that
      # carries it.
      OPAQUE_PROP_KEYS = { "data" => true }.freeze

      module_function

      # Appends +control+ to +list+ as an implicit DSL child and remembers the
      # list as its owner. Explicit children (`children:`/`controls:`, a
      # block's return value) are appended directly and are never reclaimed.
      # Overlays and services (Ruflet::Page::PRESENTED_TYPES) are presented by
      # the page, not laid out, so they are never captured implicitly.
      def attach(list, control)
        return control if Ruflet::Page.presented_control?(control)

        list << control
        control.dsl_owner = list
        control
      end

      # Takes every control passed in a child slot of +props+ back out of the
      # list that implicitly attached it, whichever builder or enclosing block
      # that was. Matching is by identity. A control already mounted on a page
      # stays in its mounted parent.
      def reclaim(props)
        each_control(props) do |control|
          owner = control.dsl_owner
          next unless owner
          next if control.runtime_page

          control.dsl_owner = nil
          index = owner.rindex { |child| child.equal?(control) }
          owner.delete_at(index) if index
        end
      end

      # Ends implicit ownership when the block that filled +list+ returns:
      # what a finished block laid out is final, so a later prop use of one of
      # its controls (often after the parent is mounted) leaves it in place.
      def release(list)
        list.each { |control| control.dsl_owner = nil if control.dsl_owner.equal?(list) }
        list
      end

      # Yields the controls passed in child slots: a prop whose value is a
      # control (`content:`, `title:`, `leading:`, `appbar:`, ...) or a list of
      # controls (`actions:`, `children:`/`controls:`, `tabs:`, `rows:`, and
      # extension lists such as `markers:` or `rods:`). That is the shape of
      # every child-control prop on the wire, whatever its name, so no list of
      # slot names is kept. A Hash value (style, theme, border, ...) is a value
      # object, not a child slot, and data: is opaque, so a control referenced
      # from either stays where its block put it.
      def each_control(props)
        props.each do |key, value|
          next if OPAQUE_PROP_KEYS.key?(key.to_s)

          if value.is_a?(Ruflet::Control)
            yield value
          elsif value.is_a?(Array)
            value.each { |item| yield item if item.is_a?(Ruflet::Control) }
          end
        end
      end
    end
  end
end
