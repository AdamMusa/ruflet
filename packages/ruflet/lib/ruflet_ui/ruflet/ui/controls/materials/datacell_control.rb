# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DataCellControl < Ruflet::Control
          TYPE = "datacell".freeze
          WIRE = "DataCell".freeze

          def initialize(id: nil, badge: nil, col: nil, content: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, key: nil, opacity: nil, placeholder: nil, rtl: nil, show_edit_icon: nil, tooltip: nil, visible: nil, on_double_tap: nil, on_long_press: nil, on_tap: nil, on_tap_cancel: nil, on_tap_down: nil)
            props = {}
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:placeholder] = placeholder unless placeholder.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:show_edit_icon] = show_edit_icon unless show_edit_icon.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_double_tap] = on_double_tap unless on_double_tap.nil?
            props[:on_long_press] = on_long_press unless on_long_press.nil?
            props[:on_tap] = on_tap unless on_tap.nil?
            props[:on_tap_cancel] = on_tap_cancel unless on_tap_cancel.nil?
            props[:on_tap_down] = on_tap_down unless on_tap_down.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
