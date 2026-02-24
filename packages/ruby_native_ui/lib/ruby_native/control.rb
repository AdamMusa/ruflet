# frozen_string_literal: true

require "securerandom"
require_relative "ui/control_registry"
require_relative "icon_data"
require_relative "icons/material_icon_lookup"
require_relative "icons/cupertino_icon_lookup"

module RubyNative
  class Control
    TYPE_MAP = UI::ControlRegistry::TYPE_MAP
    EVENT_PROPS = UI::ControlRegistry::EVENT_PROPS
    HOST_EXPANDED_TYPES = %w[view row column].freeze

    attr_reader :type, :id, :props, :children
    attr_accessor :wire_id, :runtime_page

    def initialize(type:, id: nil, **props)
      @type = type.to_s.downcase
      @id = (id || props.delete(:id) || "ctrl_#{SecureRandom.hex(4)}").to_s
      @children = []
      @handlers = {}
      @wire_id = nil
      @props = normalize_props(extract_handlers(preprocess_props(props)))
    end

    def on(event_name, &block)
      name = normalized_event_name(event_name)
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
      patch = {
        "_c" => TYPE_MAP.fetch(type, type.split("_").map(&:capitalize).join),
        "_i" => wire_id
      }

      internals = {}
      internals["host_positioned"] = true if type == "stack"
      internals["host_expanded"] = true if HOST_EXPANDED_TYPES.include?(type)
      patch["_internals"] = internals unless internals.empty?

      props.each { |k, v| patch[k] = serialize_value(v) }
      patch["controls"] = children.map(&:to_patch) unless children.empty?
      patch
    end

    private

    def serialize_value(value)
      case value
      when Control
        value.to_patch
      when RubyNative::IconData
        value.value
      when Array
        value.map { |v| serialize_value(v) }
      when Hash
        value.transform_values { |v| serialize_value(v) }
      else
        value
      end
    end

    def extract_handlers(input)
      output = input.dup

      EVENT_PROPS.each do |prop, event_name|
        string_prop = prop.to_s
        next unless output.key?(prop) || output.key?(string_prop)

        handler = output.key?(prop) ? output.delete(prop) : output.delete(string_prop)
        @handlers[event_name] = handler if handler.respond_to?(:call)
        output["on_#{event_name}"] = true
      end

      output
    end

    def normalize_props(hash)
      hash.each_with_object({}) do |(k, v), result|
        key = k.to_s
        mapped_key = key
        value =
          if v.is_a?(Symbol)
            v.to_s
          elsif v.is_a?(RubyNative::IconData)
            v.value
          else
            v
          end
        value = normalize_icon_prop(mapped_key, value)
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
      codepoint = resolve_icon_codepoint(value)
      codepoint.nil? ? value : codepoint
    end

    def icon_prop_key?(key)
      key == "icon" || key.end_with?("_icon")
    end

    def resolve_icon_codepoint(value)
      return nil unless value.is_a?(Integer) || value.is_a?(Symbol) || value.is_a?(String)

      codepoint = RubyNative::MaterialIconLookup.codepoint_for(value)
      if codepoint.nil? || (value.is_a?(Integer) && codepoint == value)
        cupertino = RubyNative::CupertinoIconLookup.codepoint_for(value)
        codepoint = cupertino unless cupertino.nil?
      end
      codepoint
    end

    def normalized_event_name(event_name)
      event_name.to_s.sub(/\Aon_/, "")
    end
  end
end
