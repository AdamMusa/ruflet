# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class SnackBarControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "snackbar", id: id, **props)
        end

        private

        def preprocess_props(props)
          mapped = props.dup
          key = if mapped.key?(:duration)
                  :duration
                elsif mapped.key?("duration")
                  "duration"
                end
          return mapped unless key

          mapped[key] = normalize_duration_ms(mapped[key])
          mapped
        end

        def normalize_duration_ms(value)
          return value.to_i if value.is_a?(Numeric)
          return value.to_i if value.is_a?(String) && value.match?(/\A\d+(\.\d+)?\z/)

          parts =
            if value.is_a?(Hash)
              value
            elsif value.respond_to?(:to_h)
              value.to_h
            else
              nil
            end
          return value unless parts.is_a?(Hash)

          days = read_number(parts, "days")
          hours = read_number(parts, "hours")
          minutes = read_number(parts, "minutes")
          seconds = read_number(parts, "seconds")
          milliseconds = read_number(parts, "milliseconds")
          microseconds = read_number(parts, "microseconds")

          total_ms = 0.0
          total_ms += days * 86_400_000.0
          total_ms += hours * 3_600_000.0
          total_ms += minutes * 60_000.0
          total_ms += seconds * 1_000.0
          total_ms += milliseconds
          total_ms += microseconds / 1000.0
          total_ms.round
        end

        def read_number(parts, key)
          raw = parts[key] || parts[key.to_sym]
          return 0.0 if raw.nil?
          return raw.to_f if raw.is_a?(Numeric)
          return raw.to_f if raw.is_a?(String) && raw.match?(/\A-?\d+(\.\d+)?\z/)

          0.0
        end
      end
    end
  end
end
