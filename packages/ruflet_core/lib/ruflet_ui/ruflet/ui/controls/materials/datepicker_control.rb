# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DatePickerControl < Ruflet::Control
          TYPE = "datepicker".freeze
          WIRE = "DatePicker".freeze

          KEYWORDS = [:adaptive, :badge, :barrier_color, :cancel_text, :col, :confirm_text, :current_date, :data, :date_picker_mode, :disabled, :entry_mode, :error_format_text, :error_invalid_text, :expand, :expand_loose, :field_hint_text, :field_label_text, :first_date, :help_text, :inset_padding, :key, :keyboard_type, :last_date, :locale, :modal, :opacity, :open, :rtl, :switch_to_calendar_icon, :switch_to_input_icon, :tooltip, :value, :visible, :on_change, :on_dismiss, :on_entry_mode_change].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end

        end
      end
    end
  end
end
