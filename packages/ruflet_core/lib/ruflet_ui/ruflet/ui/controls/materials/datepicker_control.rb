# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DatePickerControl < Ruflet::Control
          TYPE = "datepicker".freeze
          WIRE = "DatePicker".freeze

          def initialize(id: nil, adaptive: nil, badge: nil, barrier_color: nil, cancel_text: nil, col: nil, confirm_text: nil, current_date: nil, data: nil, date_picker_mode: nil, disabled: nil, entry_mode: nil, error_format_text: nil, error_invalid_text: nil, expand: nil, expand_loose: nil, field_hint_text: nil, field_label_text: nil, first_date: nil, help_text: nil, inset_padding: nil, key: nil, keyboard_type: nil, last_date: nil, locale: nil, modal: nil, opacity: nil, open: nil, rtl: nil, switch_to_calendar_icon: nil, switch_to_input_icon: nil, tooltip: nil, value: nil, visible: nil, on_change: nil, on_dismiss: nil, on_entry_mode_change: nil)
            validate_date_range!(first_date, last_date, value)

            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:barrier_color] = barrier_color unless barrier_color.nil?
            props[:cancel_text] = cancel_text unless cancel_text.nil?
            props[:col] = col unless col.nil?
            props[:confirm_text] = confirm_text unless confirm_text.nil?
            props[:current_date] = current_date unless current_date.nil?
            props[:data] = data unless data.nil?
            props[:date_picker_mode] = date_picker_mode unless date_picker_mode.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:entry_mode] = entry_mode unless entry_mode.nil?
            props[:error_format_text] = error_format_text unless error_format_text.nil?
            props[:error_invalid_text] = error_invalid_text unless error_invalid_text.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:field_hint_text] = field_hint_text unless field_hint_text.nil?
            props[:field_label_text] = field_label_text unless field_label_text.nil?
            props[:first_date] = first_date unless first_date.nil?
            props[:help_text] = help_text unless help_text.nil?
            props[:inset_padding] = inset_padding unless inset_padding.nil?
            props[:key] = key unless key.nil?
            props[:keyboard_type] = keyboard_type unless keyboard_type.nil?
            props[:last_date] = last_date unless last_date.nil?
            props[:locale] = locale unless locale.nil?
            props[:modal] = modal unless modal.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:open] = open unless open.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:switch_to_calendar_icon] = switch_to_calendar_icon unless switch_to_calendar_icon.nil?
            props[:switch_to_input_icon] = switch_to_input_icon unless switch_to_input_icon.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            props[:on_entry_mode_change] = on_entry_mode_change unless on_entry_mode_change.nil?
            super(type: TYPE, id: id, **props)
          end

          private

          def validate_date_range!(first_date, last_date, value)
            first = first_date || "1900-01-01"
            last = last_date || "2050-01-01"
            raise ArgumentError, "date_picker first_date must be before or equal to last_date" if date_key(first) > date_key(last)
            return if value.nil?

            raise ArgumentError, "date_picker value must be on or after first_date" if date_key(value) < date_key(first)
            raise ArgumentError, "date_picker value must be on or before last_date" if date_key(value) > date_key(last)
          end

          def date_key(value)
            value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
          end
        end
      end
    end
  end
end
