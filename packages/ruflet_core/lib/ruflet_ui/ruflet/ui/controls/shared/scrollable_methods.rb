# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      # Imperative methods shared by every control whose Flutter renderer is a
      # scroll view (ListView, GridView, Column, Row, View, ReorderableListView).
      # They invoke the method of the same name on the client; a control that is
      # not mounted on a page yet has no client and the call returns nil.
      module ScrollableMethods
        # Scrolls the control's own scroll view.
        #
        #   offset:     absolute position in logical pixels; negative values count
        #               from the end (-1 = the very end)
        #   delta:      relative move from the current position
        #   scroll_key: key of a descendant control to bring into view
        #   duration:   animation length in milliseconds (0/nil jumps)
        #   curve:      animation curve name, e.g. "easeOut"
        def scroll_to(offset: nil, delta: nil, scroll_key: nil, duration: nil, curve: nil, timeout: 10, on_result: nil)
          args = {}
          args["offset"] = offset unless offset.nil?
          args["delta"] = delta unless delta.nil?
          args["scroll_key"] = scroll_key unless scroll_key.nil?
          args["duration"] = duration unless duration.nil?
          args["curve"] = curve unless curve.nil?
          runtime_page&.invoke(self, "scroll_to", args: args, timeout: timeout, on_result: on_result)
        end
      end
    end
  end
end
