# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TextSpanControl < Ruflet::Control
          TYPE = "textspan".freeze
          WIRE = "TextSpan".freeze

          def initialize(id: nil, badge: nil, col: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, key: nil, opacity: nil, rtl: nil, semantics_label: nil, spans: nil, spell_out: nil, style: nil, text: nil, tooltip: nil, url: nil, visible: nil, on_click: nil, on_enter: nil, on_exit: nil)
            props = {}
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:semantics_label] = semantics_label unless semantics_label.nil?
            props[:spans] = spans unless spans.nil?
            props[:spell_out] = spell_out unless spell_out.nil?
            props[:style] = style unless style.nil?
            props[:text] = text unless text.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:url] = url unless url.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_click] = on_click unless on_click.nil?
            props[:on_enter] = on_enter unless on_enter.nil?
            props[:on_exit] = on_exit unless on_exit.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
