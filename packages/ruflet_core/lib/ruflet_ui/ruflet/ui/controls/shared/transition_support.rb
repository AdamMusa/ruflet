# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      # Checks shared by the explicit transition controls (fade_transition,
      # rotation_transition, scale_transition, slide_transition,
      # size_transition) and the clip controls (clip_oval,
      # clip_rsuperellipse). Each check raises ArgumentError naming the
      # keyword and the value, and returns what goes on the wire.
      #
      # Runs on the embedded mruby VM too: no regexps, no Set.
      module TransitionSupport
        module_function

        # Ruflet's animation length elsewhere (animated_switcher,
        # animate_opacity: true, ...): one second.
        DEFAULT_DURATION_MS = 1000

        # The keywords every transition takes on top of the common layout
        # keywords: what animates, how long, and how it plays.
        TIMING_KEYWORDS = %i[animating begin curve delay duration end repeat reverse].freeze

        # The engine's curve names (Flutter's Curves), compared without
        # underscores or case: :ease_in_out, "easeInOut" and "easeinout" are
        # one curve.
        CURVES = %w[
          bouncein bounceinout bounceout decelerate ease easein easeinback easeincirc easeincubic
          easeinexpo easeinout easeinoutback easeinoutcirc easeinoutcubic easeinoutcubicemphasized
          easeinoutexpo easeinoutquad easeinoutquart easeinoutquint easeinoutsine easeinquad
          easeinquart easeinquint easeinsine easeintolinear easeout easeoutback easeoutcirc
          easeoutcubic easeoutexpo easeoutquad easeoutquart easeoutquint easeoutsine elasticin
          elasticinout elasticout fastlineartosloweasein fastoutslowin linear lineartoeaseout
          slowmiddle
        ].freeze

        CLIP_BEHAVIORS = %w[none hardedge antialias antialiaswithsavelayer].freeze

        AXES = %w[horizontal vertical].freeze

        BORDER_RADIUS_CORNERS = %w[top_left top_right bottom_left bottom_right].freeze

        # Rejects keywords the control does not take and drops nil values.
        def known_props(props, keywords)
          unknown = props.keys.reject { |key| keywords.include?(key) }
          raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?

          props.reject { |_key, value| value.nil? }
        end

        # The props of a transition: known keywords only, nil values dropped,
        # duration (default one second), delay, curve and the play flags
        # checked. begin/end are left to the control.
        def timing_props(props, keywords)
          props = known_props(props, keywords)
          props[:duration] = milliseconds(:duration, props.fetch(:duration, DEFAULT_DURATION_MS))
          props[:delay] = milliseconds(:delay, props[:delay]) if props.key?(:delay)
          props[:curve] = curve(props[:curve]) if props.key?(:curve)
          %i[repeat reverse animating].each do |flag|
            props[flag] = boolean(flag, props[flag]) if props.key?(flag)
          end
          props
        end

        # A length in milliseconds, as Ruflet.duration(...) returns it.
        def milliseconds(name, value)
          return value if finite_number?(value) && value >= 0

          raise ArgumentError,
                "#{name} must be a non-negative number of milliseconds (see Ruflet.duration), got #{value.inspect}"
        end

        def curve(value)
          if value.is_a?(String) || value.is_a?(Symbol)
            name = value.to_s
            return name if CURVES.include?(name.downcase.delete("_"))
          end

          raise ArgumentError, "curve must be a curve name such as \"ease_in_out\", got #{value.inspect}"
        end

        def boolean(name, value)
          return value if value == true || value == false

          raise ArgumentError, "#{name} must be true or false, got #{value.inspect}"
        end

        # A finite number, optionally within [min, max].
        def number(name, value, min: nil, max: nil)
          valid = finite_number?(value) && (min.nil? || value >= min) && (max.nil? || value <= max)
          return value if valid

          range =
            if min && max then " between #{min} and #{max}"
            elsif min then " of at least #{min}"
            else ""
            end
          raise ArgumentError, "#{name} must be a number#{range}, got #{value.inspect}"
        end

        # An offset as { x:, y: } (fractions of the content's size), or a
        # Ruflet::Offset. Sent as { "x" => x, "y" => y }.
        def offset(name, value)
          value = { "x" => value.x, "y" => value.y } if !value.is_a?(Hash) && value.respond_to?(:x) && value.respond_to?(:y)
          point(name, value, "an offset { x:, y: }")
        end

        # An alignment as { x:, y: }, -1..1 on each axis (0, 0 is the centre).
        def alignment(name, value)
          point(name, value, "an alignment { x:, y: }")
        end

        def axis(value)
          name = value.to_s if value.is_a?(String) || value.is_a?(Symbol)
          return name if name && AXES.include?(name.downcase)

          raise ArgumentError, "axis must be \"vertical\" or \"horizontal\", got #{value.inspect}"
        end

        def clip_behavior(value)
          if value.is_a?(String) || value.is_a?(Symbol)
            name = value.to_s
            return name if CLIP_BEHAVIORS.include?(name.downcase.delete("_"))
          end

          raise ArgumentError,
                "clip_behavior must be none, hard_edge, anti_alias or anti_alias_with_save_layer, got #{value.inspect}"
        end

        # A corner radius for every corner, or { top_left:, top_right:,
        # bottom_left:, bottom_right: } (missing corners are square).
        def border_radius(value)
          return value if finite_number?(value) && value >= 0

          if value.is_a?(Hash) && !value.empty?
            valid = true
            value.each do |corner, radius|
              valid = false unless BORDER_RADIUS_CORNERS.include?(corner.to_s) && finite_number?(radius) && radius >= 0
            end
            return value if valid
          end

          raise ArgumentError,
                "border_radius must be a non-negative number or { top_left:, top_right:, bottom_left:, bottom_right: }, got #{value.inspect}"
        end

        def point(name, value, description)
          if value.is_a?(Hash)
            x = value.key?(:x) ? value[:x] : value["x"]
            y = value.key?(:y) ? value[:y] : value["y"]
            extra = value.keys.reject { |key| %w[x y].include?(key.to_s) }
            return { "x" => x, "y" => y } if extra.empty? && finite_number?(x) && finite_number?(y)
          end

          raise ArgumentError, "#{name} must be #{description} with numeric x and y, got #{value.inspect}"
        end

        def finite_number?(value)
          return false unless value.is_a?(Numeric)
          return true unless value.is_a?(Float)

          # x - x is 0 for every finite float and NaN for NaN and infinities.
          value - value == 0 # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
        end
      end
    end
  end
end
