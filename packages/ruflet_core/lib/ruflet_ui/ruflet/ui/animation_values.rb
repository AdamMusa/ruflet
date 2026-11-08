# frozen_string_literal: true

module Ruflet
  module UI
    # The plain values the engine reads for animations: `animate_*` props take
    # {"duration" => ms, "curve" => name} (parseAnimation), and the
    # `*animation_style` props take any of duration, reverse_duration, curve
    # and reverse_curve (parseAnimationStyle). Durations are milliseconds, or
    # Ruflet.duration-style parts such as `seconds: 1, milliseconds: 500`.
    module AnimationValues
      DURATION_PARTS = %i[days hours minutes seconds milliseconds microseconds].freeze

      module_function

      def animation(duration = nil, **props)
        parts = {}
        DURATION_PARTS.each { |part| parts[part] = props.delete(part) if props.key?(part) }
        curve = props.delete(:curve)
        raise ArgumentError, "unknown animation keywords: #{props.keys.join(', ')}" unless props.empty?
        raise ArgumentError, "give an animation duration or duration parts, not both" if duration && !parts.empty?

        duration = parts unless parts.empty?
        value = { "duration" => milliseconds(duration.nil? ? 0 : duration, "duration") }
        value["curve"] = curve.to_s unless curve.nil?
        value
      end

      def animation_style(duration: nil, reverse_duration: nil, curve: nil, reverse_curve: nil)
        style = {}
        style["duration"] = milliseconds(duration, "duration") unless duration.nil?
        style["reverse_duration"] = milliseconds(reverse_duration, "reverse_duration") unless reverse_duration.nil?
        style["curve"] = curve.to_s unless curve.nil?
        style["reverse_curve"] = reverse_curve.to_s unless reverse_curve.nil?
        style
      end

      def milliseconds(value, name)
        value = Ruflet::DSL.duration(**value.each_with_object({}) { |(k, v), out| out[k.to_sym] = v }) if value.is_a?(Hash)
        return value if value.is_a?(Numeric) && value >= 0

        raise ArgumentError, "#{name} must be a non-negative number of milliseconds, got #{value.inspect}"
      end
    end
  end
end
