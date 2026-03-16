# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class KeyboardListenerControl < Ruflet::Control
          TYPE = "keyboardlistener".freeze
          WIRE = "KeyboardListener".freeze

          def initialize(id: nil, autofocus: nil, badge: nil, col: nil, content: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, include_semantics: nil, key: nil, opacity: nil, rtl: nil, tooltip: nil, visible: nil, on_key_down: nil, on_key_repeat: nil, on_key_up: nil)
            props = {}
            props[:autofocus] = autofocus unless autofocus.nil?
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:include_semantics] = include_semantics unless include_semantics.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_key_down] = on_key_down unless on_key_down.nil?
            props[:on_key_repeat] = on_key_repeat unless on_key_repeat.nil?
            props[:on_key_up] = on_key_up unless on_key_up.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
