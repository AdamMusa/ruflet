# frozen_string_literal: true

module Ruflet
  # The input controls a Form validates, resets and saves together, and the
  # Ruby-only options they take:
  #
  #   validator:         ->(value) { "error message" or nil }
  #   on_saved:          ->(value) { ... }, called by form.save
  #   autovalidate_mode: "disabled" (default), "always", "on_user_interaction"
  #                      or "on_unfocus" (also accepted by the form itself)
  #
  # Like event handlers these stay in Ruby and are never serialized.
  module FormFields
    AUTOVALIDATE_MODES = %w[disabled always on_user_interaction on_unfocus].freeze
    OPTION_KEYS = %w[validator on_saved autovalidate_mode].freeze

    # Per wire type:
    #   value:   the prop holding the value (alternatives: the first one the
    #            control declares); range: the two props of a range value
    #   default: the value an unset prop stands for (default_from: a prop)
    #   change:  the event the client sends when the user changes the value
    #   error:   the prop that shows a validation error, when the control has
    #            one; error_flag: it is a boolean error state, not a message
    SPECS = {
      "TextField" => { value: %w[value], default: "", change: "change", error: "error" },
      "Dropdown" => { value: %w[value], change: "select", error: "error_text" },
      "Checkbox" => { value: %w[value], default: false, change: "change", error: "error", error_flag: true },
      "Switch" => { value: %w[value], default: false, change: "change" },
      "RadioGroup" => { value: %w[value], change: "change" },
      "Slider" => { value: %w[value], default_from: "min", default: 0.0, change: "change" },
      "RangeSlider" => { range: %w[start_value end_value], change: "change" },
      "DatePicker" => { value: %w[value], change: "change" },
      "TimePicker" => { value: %w[value], change: "change" },
      "SegmentedButton" => { value: %w[selected selected_index], change: "change" }
    }.freeze

    module_function

    def field?(control)
      SPECS.key?(control.wire_type)
    end

    def form?(control)
      control.wire_type == "Form"
    end

    def text_field?(control)
      control.wire_type == "TextField"
    end

    # Removes the form options from +props+ (Symbol or String keys) and
    # returns them as a Hash keyed by String.
    def extract_options!(props)
      options = {}
      return options unless props.respond_to?(:key?)

      OPTION_KEYS.each do |name|
        [name.to_sym, name].each do |key|
          next unless props.key?(key)

          options[name] = props.delete(key)
        end
      end
      options
    end

    def normalize_mode(value)
      return nil if value.nil?

      mode = value.to_s
      return mode if AUTOVALIDATE_MODES.include?(mode)

      raise ArgumentError, "autovalidate_mode must be one of #{AUTOVALIDATE_MODES.join(', ')}, got #{value.inspect}"
    end

    def require_callable!(name, value)
      return if value.nil? || value.respond_to?(:call)

      raise ArgumentError, "#{name} must be callable (a lambda, proc or method), got #{value.inspect}"
    end

    def require_field!(control, name)
      return if field?(control)

      raise ArgumentError,
            "#{name} is accepted by form fields only (#{SPECS.keys.join(', ')}), not #{control.wire_type}"
    end

    def spec(control)
      SPECS.fetch(control.wire_type)
    end

    def change_event(control)
      spec(control)[:change]
    end

    def declares?(control, prop)
      control.send(:property_name_lookup).key?(prop)
    end

    def declares_event?(control, event)
      control.send(:event_name_lookup).key?(event)
    end

    # The field's current value, as its validator, on_saved and form.values
    # see it.
    def value_of(control)
      field_spec = spec(control)
      range = field_spec[:range]
      return range.map { |prop| control.props[prop] } if range

      value = control.props[value_prop(control)]
      return value unless value.nil?
      return nil if control.props["tristate"] == true

      from = field_spec[:default_from]
      fallback = from ? control.props[from] : nil
      fallback.nil? ? field_spec[:default] : fallback
    end

    # A value kept apart from the field's props (form.reset's snapshot).
    def copy(value)
      case value
      when String, Array, Hash then value.dup
      else value
      end
    end

    def write_value(control, value)
      range = spec(control)[:range]
      if range
        values = value.is_a?(Array) ? value : [nil, nil]
        range.each_with_index { |prop, index| control.props[prop] = values[index] }
      else
        control.props[value_prop(control)] = value
      end
    end

    def value_prop(control)
      props = spec(control)[:value]
      props.find { |prop| control.props.key?(prop) } ||
        props.find { |prop| declares?(control, prop) } ||
        props.first
    end

    # Runs the field's validator on its current value: the error message, or
    # nil when the field is valid (or has no validator).
    def run_validator(control)
      validator = control.validator
      return nil unless validator

      result = validator.call(value_of(control))
      case result
      when nil, false then nil
      when String then result
      when Symbol then result.to_s
      else
        raise ArgumentError,
              "#{control.wire_type} validator must return an error message String or nil, got #{result.inspect}"
      end
    end

    # Shows +message+ on the field (nil clears it): its error prop when it has
    # one, and always field.validation_error.
    def show_error(control, message)
      control.validation_error = message
      field_spec = spec(control)
      prop = field_spec[:error]
      return if prop.nil? || !declares?(control, prop)

      if message.nil?
        control.props.delete(prop)
      else
        control.props[prop] = field_spec[:error_flag] ? true : message
      end
    end

    # form.values key: the field's `key`, or its id.
    def key_of(control)
      key = control.props["key"]
      case key
      when String then key.empty? ? control.id : key
      when Symbol, Numeric then key.to_s
      else control.id
      end
    end
  end
end
