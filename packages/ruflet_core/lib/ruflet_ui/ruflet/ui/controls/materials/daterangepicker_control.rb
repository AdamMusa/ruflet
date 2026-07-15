# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DateRangePickerControl < Ruflet::Control
          TYPE = "daterangepicker".freeze
          WIRE = "DateRangePicker".freeze

          KEYWORDS = [:adaptive, :badge, :barrier_color, :cancel_text, :col, :confirm_text, :current_date, :data, :disabled, :end_value, :entry_mode, :error_format_text, :error_invalid_range_text, :error_invalid_text, :expand, :expand_loose, :field_end_hint_text, :field_end_label_text, :field_start_hint_text, :field_start_label_text, :first_date, :help_text, :key, :keyboard_type, :last_date, :locale, :modal, :opacity, :open, :rtl, :save_text, :start_value, :switch_to_calendar_icon, :switch_to_input_icon, :tooltip, :visible, :on_change, :on_dismiss].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              value = Ruflet::Protocol.date_time(value) if %i[start_value end_value first_date last_date current_date].include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end

        end
      end
    end
  end
end
