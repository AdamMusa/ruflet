# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SnackBarActionControl < Ruflet::Control
          TYPE = "snackbaraction".freeze
          WIRE = "SnackBarAction".freeze

          def initialize(id: nil, badge: nil, bgcolor: nil, col: nil, data: nil, disabled: nil, disabled_bgcolor: nil, disabled_text_color: nil, expand: nil, expand_loose: nil, key: nil, label: nil, opacity: nil, rtl: nil, text_color: nil, tooltip: nil, visible: nil, on_click: nil)
            raise ArgumentError, "snack_bar_action requires label" if label.nil?

            props = {}
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:disabled_bgcolor] = disabled_bgcolor unless disabled_bgcolor.nil?
            props[:disabled_text_color] = disabled_text_color unless disabled_text_color.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:text_color] = text_color unless text_color.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_click] = on_click unless on_click.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
