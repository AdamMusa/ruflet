# frozen_string_literal: true

begin
require "securerandom"
rescue LoadError
  nil
end
require_relative "icon_data"
require_relative "icons/material_icon_lookup"
require_relative "icons/cupertino_icon_lookup"
require "set"

module Ruflet
  class Control
    HOST_EXPANDED_TYPES = %w[view row column].freeze

    attr_reader :type, :id, :props, :children
    attr_accessor :wire_id, :runtime_page

    def initialize(type:, id: nil, **props)
      @type = type.to_s.downcase
      @id = (id || props.delete(:id) || "ctrl_#{self.class.generate_id}").to_s
      @children = []
      @handlers = {}
      @wire_id = nil
      @props = normalize_props(extract_handlers(preprocess_props(props)))
    end

    def on(event_name, &block)
      name = normalized_event_name(event_name)
      validate_event_name!(name)
      @handlers[name] = block
      @props["on_#{name}"] = true
      runtime_page&.update(self, "on_#{name}": true) if wire_id
      self
    end

    def emit(event_name, event)
      handler = @handlers[normalized_event_name(event_name)]
      return false unless handler

      handler.call(event)
      true
    end

    def has_handler?(event_name)
      @handlers.key?(normalized_event_name(event_name))
    end

    def to_patch
      wire_type = schema_wire_type_for_class
      if wire_type.nil?
        compact_type_key = type.delete("_")
        wire_type = type_map[type] || type_map[compact_type_key]
      end
      raise ArgumentError, "Unknown control type: #{type}" unless wire_type
      patch = {
        "_c" => wire_type,
        "_i" => wire_id
      }

      internals = {}
      internals["host_positioned"] = true if type == "stack"
      internals["host_expanded"] = true if HOST_EXPANDED_TYPES.include?(type)
      patch["_internals"] = internals unless internals.empty?

      props.each { |k, v| patch[k] = serialize_value(v) }
      patch["controls"] = children.map(&:to_patch) unless children.empty?
      if ENV["RUFLET_DEBUG"] == "1" && type == "floatingactionbutton"
        Kernel.warn("[to_patch] #{patch.inspect}")
      end
      patch
    end

    private

    class << self
      def generate_id
        if defined?(SecureRandom) && SecureRandom.respond_to?(:hex)
          SecureRandom.hex(4)
        else
          format("%08x", rand(0..0xffff_ffff))
        end
      end
    end

    def serialize_value(value)
      case value
      when Control
        value.to_patch
      when Ruflet::IconData
        value.value
      when Array
        value.map { |v| serialize_value(v) }
      when Hash
        value.transform_values { |v| serialize_value(v) }
      else
        value.respond_to?(:to_h) ? serialize_value(value.to_h) : value
      end
    end

    def extract_handlers(input)
      output = input.dup
      allowed_events = event_names
      allowed_events_set = allowed_events.to_set

      output.keys.each do |key|
        key_string = key.to_s
        next unless key_string.start_with?("on_")

        event_name = normalized_event_name(key_string)
        if allowed_events.any? && !allowed_events_set.include?(event_name)
          raise ArgumentError, "Unknown event `#{key_string}` for control type `#{type}`"
        end

        handler = output.delete(key)
        @handlers[event_name] = handler if handler.respond_to?(:call)
        output["on_#{event_name}"] = true
      end

      event_props.each do |prop, event_name|
        string_prop = prop.to_s
        next unless output.key?(prop) || output.key?(string_prop)
        next if allowed_events.any? && !allowed_events_set.include?(event_name)

        handler = output.key?(prop) ? output.delete(prop) : output.delete(string_prop)
        @handlers[event_name] = handler if handler.respond_to?(:call)
        output["on_#{event_name}"] = true
      end

      output
    end

    def normalize_props(hash)
      allowed_props = property_names
      normalized_allowed = allowed_props.to_set

      hash.each_with_object({}) do |(k, v), result|
        key = k.to_s
        mapped_key = key
        if strict_schema_enforced?(allowed_props) &&
            !mapped_key.start_with?("_") &&
            !mapped_key.start_with?("on_") &&
            !normalized_allowed.include?(mapped_key)
          raise ArgumentError, "Unknown attribute `#{mapped_key}` for control type `#{type}`"
        end

        value =
          if v.is_a?(Symbol)
            v.to_s
          else
            v
          end
        value = normalize_icon_prop(mapped_key, value)
        value = value.value if value.is_a?(Ruflet::IconData)
        value = normalize_color_prop(mapped_key, value)

        result[mapped_key] = value
      end
    end

    def preprocess_props(props)
      props
    end

    def normalize_color_prop(key, value)
      return value unless value.is_a?(String)
      return value.downcase if color_prop_key?(key)

      value
    end

    def color_prop_key?(key)
      key == "color" || key == "bgcolor" || key.end_with?("_color")
    end

    def normalize_icon_prop(key, value)
      return value unless icon_prop_key?(key)
      return value if value.nil?
      return value if value.is_a?(Integer)
      return value if value.is_a?(Ruflet::IconData)

      raise ArgumentError, "#{type} #{key} must use Ruflet::MaterialIcons (or another Ruflet::IconData), not #{value.inspect}"
    end

    def icon_prop_key?(key)
      key == "icon" || key.end_with?("_icon")
    end

    def normalized_event_name(event_name)
      event_name.to_s.sub(/\Aon_/, "")
    end

    def validate_event_name!(event_name)
      events = event_names
      return if events.empty? || events.include?(event_name)

      raise ArgumentError, "Unknown event `on_#{event_name}` for control type `#{type}`"
    end

    def strict_schema_enforced?(allowed_props)
      !allowed_props.empty?
    end

    def property_names
      constructor_keywords_for_schema_class
        .reject { |name| name.to_s.start_with?("on_") }
        .map(&:to_s)
    end

    def event_names
      constructor_keywords_for_schema_class
        .select { |name| name.to_s.start_with?("on_") }
        .map { |name| name.to_s.sub(/\Aon_/, "") }
    end

    def schema_wire_type_for_class
      return nil unless self.class.const_defined?(:WIRE)

      self.class::WIRE.to_s
    end

    def schema_class_for_validation
      if self.class != Ruflet::Control && has_explicit_initialize_keywords?(self.class)
        return self.class
      end
      begin
        require_relative "ui/control_factory"
        mapped = UI::ControlFactory::CLASS_MAP[type]
        return mapped if mapped && has_explicit_initialize_keywords?(mapped)
      rescue LoadError
        nil
      end

      begin
        require_relative "ui/controls/ruflet_controls"
        mapped = UI::Controls::RufletControls::CLASS_MAP[type]
        return mapped if mapped && has_explicit_initialize_keywords?(mapped)
      rescue LoadError
        nil
      end

      nil
    end

    def constructor_keywords_for_schema_class
      schema_class = schema_class_for_validation
      return [] unless schema_class

      schema_class.instance_method(:initialize).parameters
                 .select { |kind, _| kind == :key || kind == :keyreq }
                 .map { |_, name| name }
                 .reject { |name| name == :id }
    rescue StandardError
      []
    end

    def has_explicit_initialize_keywords?(klass)
      params = klass.instance_method(:initialize).parameters
      params.any? { |kind, _| kind == :key || kind == :keyreq }
    rescue StandardError
      false
    end

    def type_map
      require_relative "ui/control_registry"
      UI::ControlRegistry::TYPE_MAP
    end

    def event_props
      require_relative "ui/control_registry"
      UI::ControlRegistry::EVENT_PROPS
    end
  end
end
