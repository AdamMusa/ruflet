# frozen_string_literal: true

module Ruflet
  module Rails
    module HtmlDsl
      # Compares the control tree already mounted on a screen with the one just
      # built from fresh markup, and reports the minimum set of prop updates
      # that turns the first into the second.
      #
      # Re-rendering a screen in place otherwise means shipping every control
      # on it to change one value — a counter tick re-sends the heading, both
      # buttons and the caption to move a single digit, and the client rebuilds
      # that subtree (losing scroll position and any transient widget state).
      #
      # The diff is deliberately conservative: it only reports updates when the
      # two trees have exactly the same shape (same control types, same number
      # of children, same prop-held controls, in the same order). Any structural
      # difference returns nil, and the caller replaces the body wholesale as
      # before. Shape changes are where a diff would be subtly wrong, and they
      # are also the case where a full replace costs what it should.
      class ControlDiff
        # Props whose values are server-side plumbing, never wire state.
        SKIPPED_PROPS = %w[key].freeze

        def initialize(old_tree, new_tree)
          @old_tree = old_tree
          @new_tree = new_tree
        end

        # [[mounted_control, {prop => value}], …], or nil when the shape moved.
        def updates
          @updates = []
          return nil unless walk(@old_tree, @new_tree)

          @updates
        end

        private

        def walk(old_node, new_node)
          return true if old_node.nil? && new_node.nil?
          return false if old_node.nil? || new_node.nil?

          if old_node.is_a?(Array) || new_node.is_a?(Array)
            return false unless old_node.is_a?(Array) && new_node.is_a?(Array)
            return false unless old_node.length == new_node.length

            return old_node.each_with_index.all? { |item, i| walk(item, new_node[i]) }
          end

          return old_node == new_node unless control?(old_node) || control?(new_node)
          return false unless control?(old_node) && control?(new_node)
          return false unless old_node.type == new_node.type
          return false unless old_node.children.length == new_node.children.length

          return false unless compare_props(old_node, new_node)

          old_node.children.each_with_index.all? { |child, i| walk(child, new_node.children[i]) }
        end

        def compare_props(old_node, new_node)
          keys = (old_node.props.keys | new_node.props.keys) - SKIPPED_PROPS
          changed = {}

          keys.each do |key|
            old_value = old_node.props[key]
            new_value = new_node.props[key]

            # A prop holding controls is structure: recurse instead of comparing.
            if holds_controls?(old_value) || holds_controls?(new_value)
              return false unless walk(old_value, new_value)

              next
            end

            changed[key.to_sym] = new_value unless old_value == new_value
          end

          # The fresh tree carries handlers bound to this render (a button's
          # on-click closes over the screen it was built for). Move them onto
          # the mounted control so taps keep working after a patch; handlers
          # live server-side, so this costs nothing on the wire.
          rebind_handlers(old_node, new_node)

          @updates << [old_node, changed] unless changed.empty?
          true
        end

        def rebind_handlers(old_node, new_node)
          handlers = new_node.instance_variable_get(:@handlers)
          return if handlers.nil? || handlers.empty?

          old_node.instance_variable_set(:@handlers, handlers)
        end

        def control?(node)
          node.is_a?(Ruflet::Control)
        end

        def holds_controls?(value)
          return true if control?(value)
          return value.any? { |item| control?(item) } if value.is_a?(Array)

          false
        end
      end
    end
  end
end
