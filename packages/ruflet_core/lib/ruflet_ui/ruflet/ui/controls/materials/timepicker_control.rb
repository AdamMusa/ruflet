# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TimePickerControl < Ruflet::Control
          TYPE = "timepicker".freeze
          WIRE = "TimePicker".freeze

          def initialize(id: nil, adaptive: nil, badge: nil, barrier_color: nil, cancel_text: nil, col: nil, confirm_text: nil, data: nil, disabled: nil, entry_mode: nil, error_invalid_text: nil, expand: nil, expand_loose: nil, help_text: nil, hour_format: nil, hour_label_text: nil, key: nil, locale: nil, minute_label_text: nil, modal: nil, opacity: nil, open: nil, orientation: nil, rtl: nil, switch_to_input_icon: nil, switch_to_timer_icon: nil, tooltip: nil, value: nil, visible: nil, on_change: nil, on_dismiss: nil, on_entry_mode_change: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:barrier_color] = barrier_color unless barrier_color.nil?
            props[:cancel_text] = cancel_text unless cancel_text.nil?
            props[:col] = col unless col.nil?
            props[:confirm_text] = confirm_text unless confirm_text.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:entry_mode] = entry_mode unless entry_mode.nil?
            props[:error_invalid_text] = error_invalid_text unless error_invalid_text.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:help_text] = help_text unless help_text.nil?
            props[:hour_format] = hour_format unless hour_format.nil?
            props[:hour_label_text] = hour_label_text unless hour_label_text.nil?
            props[:key] = key unless key.nil?
            props[:locale] = locale unless locale.nil?
            props[:minute_label_text] = minute_label_text unless minute_label_text.nil?
            props[:modal] = modal unless modal.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:open] = open unless open.nil?
            props[:orientation] = orientation unless orientation.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:switch_to_input_icon] = switch_to_input_icon unless switch_to_input_icon.nil?
            props[:switch_to_timer_icon] = switch_to_timer_icon unless switch_to_timer_icon.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            props[:on_entry_mode_change] = on_entry_mode_change unless on_entry_mode_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
