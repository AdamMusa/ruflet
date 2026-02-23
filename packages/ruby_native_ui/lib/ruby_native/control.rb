# frozen_string_literal: true

require "securerandom"
require_relative "ui/control_registry"

module RubyNative
  class Control
    TYPE_MAP = UI::ControlRegistry::TYPE_MAP
    EVENT_PROPS = UI::ControlRegistry::EVENT_PROPS

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

      # Flet uses control internals to enable layout behaviors like absolute
      # positioning for Stack children.
      patch["_internals"] = { "host_positioned" => true } if type == "stack"

      props.each { |k, v| patch[k] = serialize_value(v) }
      patch["controls"] = children.map(&:to_patch) unless children.empty?
      patch
    end

    private

    def serialize_value(value)
      case value
      when Control
        value.to_patch
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
        value = v.is_a?(Symbol) ? v.to_s : v

        result[mapped_key] = value
      end
    end

    def preprocess_props(props)
      props
    end

    def normalized_event_name(event_name)
      event_name.to_s.sub(/\Aon_/, "")
    end
  end
end
