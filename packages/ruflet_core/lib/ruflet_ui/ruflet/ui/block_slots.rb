# frozen_string_literal: true

require_relative "build_scope"
require_relative "prop_controls"

module Ruflet
  module UI
    # What a builder does with a block, and the warnings for what it cannot
    # use.
    #
    # A builder whose control has a `controls` list (column, list_view,
    # expansion_tile, ...) hands its block to build_widget, which appends the
    # block's controls to that list. Any other child slot is filled through
    # BlockSlotMethods#fill_block_slot: the block runs in a nested
    # WidgetBuilder, and its first control becomes `content`, or all of them
    # become the list slot (`actions`, `destinations`, `options`, `items`,
    # `tabs`, `rows`, `shapes`). A call that passes the slot explicitly keeps
    # what it did before blocks were read there.
    #
    # A control that is pressed (a `content` slot and an `on_click` event:
    # the buttons, the floating action button, menu items, sheet and dialog
    # actions) never runs its block. `elevated_button(on_click: h) { save }`
    # read as a handler would run `save` while building the page, so its
    # block is reported once and ignored, as it always was.
    module BlockSlots
      @warned = {}

      class << self
        # Prints +message+ once per +key+ for the life of the process, so a
        # view rebuilt on every event does not repeat it.
        def warn_once(key, message)
          return if @warned.key?(key)

          @warned[key] = true
          Kernel.warn("[ruflet] #{message}")
        end

        # For tests: forget which warnings were printed.
        def reset_warnings!
          @warned.clear
        end

        # A children list keeps only controls. nil and false are left out
        # silently, as conditional children (`[a, (b if c)]`) rely on; anything
        # else is reported once per control type and class.
        def dropped_child(owner, child)
          return if child.nil? || child == false

          kind = child.class.name
          warn_once(
            "child:#{owner}:#{kind}",
            "#{owner} dropped a #{kind} child: a children list takes controls (wrap text in text(...)); nil and false are skipped"
          )
        end
      end
    end

    # Private helpers for the builder methods in UI::ControlMethods.
    module BlockSlotMethods
      private

      # Where services built in a slot block go. WidgetBuilder and
      # Ruflet::DSL::App return their own list, as their blocks do.
      def block_services = nil

      def block_slot_given?(props, slot)
        !(props[slot].nil? && props[slot.to_s].nil?)
      end

      # The controls +block+ builds, collected as WidgetBuilder#control
      # collects a block's: everything built in it, plus a control it returns
      # that was built elsewhere.
      def block_slot_children(block)
        nested = Ruflet::WidgetBuilder.new(services: block_services)
        result = BuildScope.within(nested) { nested.instance_eval(&block) }
        children = PropControls.release(nested.children)
        if result.is_a?(Ruflet::Control) && !children.any? { |child| child.equal?(result) }
          children << result
        end
        children
      end

      # Puts the controls +block+ builds into +slot+ of +props+ and returns
      # +props+. +name+ is the helper, for warnings.
      def fill_block_slot(name, slot, props, block)
        return props unless block

        if block_slot_given?(props, slot)
          BlockSlots.warn_once(
            "given:#{name}",
            "#{name} ignores its block because #{slot}: was given; pass the #{slot} or build it in the block, not both"
          )
          return props
        end

        children = block_slot_children(block)
        return props if children.empty?

        if slot == :content
          if children.length > 1
            BlockSlots.warn_once(
              "many:#{name}",
              "#{name} takes one content control, but its block built #{children.length}; keeping the first (wrap them in column { ... })"
            )
          end
          props[:content] = children.first
        else
          props[slot] = children
        end
        props
      end

      def build_with_block_slot(type, name, slot, props, block)
        build_widget(type, **fill_block_slot(name, slot, props, block))
      end

      # container, gesture_detector, pagelet, tabs, draggable, drag_target,
      # navigation_bar, navigation_rail and tab_bar ran their block before its
      # controls were put into their slot, and appended them to `controls`,
      # which their renderers never read. A call that passes the slot too
      # still does that, so its output is unchanged.
      def build_with_legacy_block_slot(type, name, slot, props, block)
        return build_widget(type, **props, &block) if block && block_slot_given?(props, slot)

        build_with_block_slot(type, name, slot, props, block)
      end

      # The block of a control that is pressed is never run (see BlockSlots).
      def ignore_block(name, block)
        return unless block

        BlockSlots.warn_once(
          "ignored:#{name}",
          "#{name} does not run its block: pass the content as an argument (#{name}(text(\"...\"))) and a click handler as on_click:"
        )
      end

      # cupertino_segmented_button and cupertino_sliding_segmented_button
      # check their children before building, so a block's controls are
      # collected first: block controls, then the ones passed, as column
      # orders them.
      def segmented_block_children(children, props, block)
        return children unless block

        passed = children || props.delete(:children) || props.delete("children") ||
                 props.delete(:controls) || props.delete("controls")
        block_slot_children(block) + Array(passed)
      end
    end
  end
end
