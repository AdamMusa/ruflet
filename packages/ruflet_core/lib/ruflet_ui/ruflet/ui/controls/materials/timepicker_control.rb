# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TimePickerControl < Ruflet::Control
          TYPE = "timepicker".freeze
          WIRE = "TimePicker".freeze

          KEYWORDS = [:adaptive, :badge, :barrier_color, :cancel_text, :col, :confirm_text, :data, :disabled, :entry_mode, :error_invalid_text, :expand, :expand_loose, :help_text, :hour_format, :hour_label_text, :key, :locale, :minute_label_text, :modal, :opacity, :open, :orientation, :rtl, :switch_to_input_icon, :switch_to_timer_icon, :tooltip, :value, :visible, :on_change, :on_dismiss, :on_entry_mode_change].freeze

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
