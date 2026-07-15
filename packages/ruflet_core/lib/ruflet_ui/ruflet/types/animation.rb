# frozen_string_literal: true

module Ruflet
  module UI
    module Types
      module AnimationCurve
        BOUNCE_IN = "bounceIn"
        BOUNCE_IN_OUT = "bounceInOut"
        BOUNCE_OUT = "bounceOut"
        DECELERATE = "decelerate"
        EASE = "ease"
        EASE_IN = "easeIn"
        EASE_IN_BACK = "easeInBack"
        EASE_IN_CIRC = "easeInCirc"
        EASE_IN_CUBIC = "easeInCubic"
        EASE_IN_EXPO = "easeInExpo"
        EASE_IN_OUT = "easeInOut"
        EASE_IN_OUT_BACK = "easeInOutBack"
        EASE_IN_OUT_CIRC = "easeInOutCirc"
        EASE_IN_OUT_CUBIC = "easeInOutCubic"
        EASE_IN_OUT_CUBIC_EMPHASIZED = "easeInOutCubicEmphasized"
        EASE_IN_OUT_EXPO = "easeInOutExpo"
        EASE_IN_OUT_QUAD = "easeInOutQuad"
        EASE_IN_OUT_QUART = "easeInOutQuart"
        EASE_IN_OUT_QUINT = "easeInOutQuint"
        EASE_IN_OUT_SINE = "easeInOutSine"
        EASE_IN_QUAD = "easeInQuad"
        EASE_IN_QUART = "easeInQuart"
        EASE_IN_QUINT = "easeInQuint"
        EASE_IN_SINE = "easeInSine"
        EASE_IN_TO_LINEAR = "easeInToLinear"
        EASE_OUT = "easeOut"
        EASE_OUT_BACK = "easeOutBack"
        EASE_OUT_CIRC = "easeOutCirc"
        EASE_OUT_CUBIC = "easeOutCubic"
        EASE_OUT_EXPO = "easeOutExpo"
        EASE_OUT_QUAD = "easeOutQuad"
        EASE_OUT_QUART = "easeOutQuart"
        EASE_OUT_QUINT = "easeOutQuint"
        EASE_OUT_SINE = "easeOutSine"
        ELASTIC_IN = "elasticIn"
        ELASTIC_IN_OUT = "elasticInOut"
        ELASTIC_OUT = "elasticOut"
        FAST_LINEAR_TO_SLOW_EASE_IN = "fastLinearToSlowEaseIn"
        FAST_OUT_SLOWIN = "fastOutSlowIn"
        LINEAR = "linear"
        LINEAR_TO_EASE_OUT = "linearToEaseOut"
        SLOW_MIDDLE = "slowMiddle"

        module_function

        def values
          constants(false).map { |name| const_get(name) }
        end
      end

      class Animation
        attr_reader :duration, :curve

        def initialize(duration: nil, curve: AnimationCurve::LINEAR)
          @duration = duration
          @curve = curve
        end

        def copy(duration: nil, curve: nil)
          self.class.new(
            duration: duration.nil? ? @duration : duration,
            curve: curve.nil? ? @curve : curve
          )
        end

        def to_h
          {}.tap do |hash|
            hash["duration"] = duration unless duration.nil?
            hash["curve"] = curve unless curve.nil?
          end
        end
      end

      class AnimationStyle
        attr_reader :duration, :reverse_duration, :curve, :reverse_curve

        def initialize(duration: nil, reverse_duration: nil, curve: nil, reverse_curve: nil)
          @duration = duration
          @reverse_duration = reverse_duration
          @curve = curve
          @reverse_curve = reverse_curve
        end

        def copy(duration: nil, reverse_duration: nil, curve: nil, reverse_curve: nil)
          self.class.new(
            duration: duration.nil? ? @duration : duration,
            reverse_duration: reverse_duration.nil? ? @reverse_duration : reverse_duration,
            curve: curve.nil? ? @curve : curve,
            reverse_curve: reverse_curve.nil? ? @reverse_curve : reverse_curve
          )
        end

        def to_h
          {}.tap do |hash|
            hash["duration"] = duration unless duration.nil?
            hash["reverse_duration"] = reverse_duration unless reverse_duration.nil?
            hash["curve"] = curve unless curve.nil?
            hash["reverse_curve"] = reverse_curve unless reverse_curve.nil?
          end
        end
      end
    end
  end
end
