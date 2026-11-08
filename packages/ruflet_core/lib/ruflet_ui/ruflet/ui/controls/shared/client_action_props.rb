# frozen_string_literal: true

require_relative "../../../client_action"

module Ruflet
  module UI
    module Controls
      # The `action:` keyword of the controls Flet calls ActionControls
      # (every button, icon button, floating action button, container, list
      # tile and text span): a Ruflet::ClientAction, or a list of them, that
      # the client performs inside the tap before it sends `click`. The value
      # is checked here and kept as its plain wire hash (or Array of hashes),
      # so serialization, diffing and `page.update` see ordinary data. The
      # outcome of each action arrives as the control's `on_action_result`.
      module ClientActionProps
        private

        def preprocess_props(props)
          mapped = super
          key = mapped.key?(:action) ? :action : "action"
          return mapped unless mapped.key?(key)

          value = mapped[key]
          return mapped if value.nil?

          copy = mapped.dup
          copy[key] = Ruflet::ClientAction.wire(value)
          copy
        end
      end
    end
  end
end
