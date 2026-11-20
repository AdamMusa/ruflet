# frozen_string_literal: true

require "json"
require_relative "events/gesture_events"

module Ruflet
  class Event
    attr_reader :name, :target, :raw_data, :data, :typed_data, :page, :control

    # Choices whose declared value the renderer reads as a String and sends
    # back as the value of the control they belong to: wire type => the props
    # it reads, first one set wins (material_dropdown.dart: an option's key,
    # else its text; radio.dart: a radio's value).
    CHOICE_VALUE_PROPS = {
      "DropdownOption" => %w[key text],
      "Option" => %w[key text],
      "Radio" => %w[value]
    }.freeze

    def initialize(name:, target:, raw_data:, page:, control:)
      @name = name
      @target = target
      @raw_data = raw_data
      @page = page
      @control = control
      @data = parse_data(raw_data)
      @typed_data = Events::GestureEventFactory.build(name, @data)
    end

    # A stable convenience accessor shared by built-in and extension events.
    # Extension event names are intentionally not part of the core typed-event
    # registry, so fall back to the same value extraction used by GenericEvent.
    def value
      return typed_data.value if typed_data&.respond_to?(:value)

      Events::GenericEvent.from_data(data).value
    end

    # This event under another name. Everything else (target, control, page,
    # raw_data, data, typed_data and so value) is the same as on the original,
    # so a handler registered under a legacy spelling of a client event can
    # see the name it was registered with.
    def with_name(name)
      copy = dup
      copy.instance_variable_set(:@name, name)
      copy
    end

    # This event as +control+ relays it under +name+ (a Form relays its
    # fields' change and submit). data stays what this event decoded for the
    # field it came from; typed_data is rebuilt for +name+.
    def relayed(name:, target:, control:)
      copy = dup
      copy.instance_variable_set(:@name, name)
      copy.instance_variable_set(:@target, target)
      copy.instance_variable_set(:@control, control)
      copy.instance_variable_set(:@typed_data, Events::GestureEventFactory.build(name, @data))
      copy
    end

    private

    # Map and list payloads arrive decoded, and a String payload that holds
    # JSON is decoded too. The exception is a String that is the control's
    # own value or text. The client syncs that String into the control
    # (update_control) right before the event that reports it: TextField
    # change and submit, Dropdown select and text_change, RadioGroup change.
    # It is what the user typed or picked, so it stays a String, even when it
    # looks like JSON ("123", "2.50", "null", "[1]").
    # One case keeps the decoded value: the renderer sends an Integer option
    # key or radio value back as "2", and the handler still gets 2.
    def parse_data(raw)
      return raw unless raw.is_a?(String)

      decoded = decode_json(raw)
      return decoded if decoded.equal?(raw)

      props = @control.respond_to?(:props) ? @control.props : nil
      return decoded unless props.is_a?(Hash)

      if props["value"] == raw
        declared_choice?(raw, decoded) ? decoded : raw
      elsif props["text"] == raw
        raw
      else
        decoded
      end
    end

    def decode_json(raw)
      return raw unless Object.const_defined?(:JSON)

      Object.const_get(:JSON).parse(raw)
    rescue StandardError
      raw
    end

    # Whether +decoded+ (not a String) is a value the app declared on one of
    # the control's choices, while no choice declares +raw+ itself.
    def declared_choice?(raw, decoded)
      return false if decoded.nil? || decoded.is_a?(String) || decoded.is_a?(Hash) || decoded.is_a?(Array)

      values = choice_values
      return false if values.include?(raw)

      values.any? { |value| !value.is_a?(String) && value == decoded }
    end

    # The declared values of the control's choices: its options, or the
    # radios inside a RadioGroup. A nested form field owns its own choices.
    def choice_values
      values = []
      return values unless @control.respond_to?(:props) && @control.respond_to?(:children)

      stack = @control.children + @control.props.values
      visited = {}
      until stack.empty?
        item = stack.pop
        if item.is_a?(Array)
          stack.concat(item)
          next
        end
        next unless item.is_a?(Ruflet::Control)
        next if visited.key?(item.object_id)

        visited[item.object_id] = true
        names = CHOICE_VALUE_PROPS[item.wire_type]
        if names
          value = nil
          names.each { |prop| value = item.props[prop] if value.nil? }
          values << value unless value.nil?
        elsif !FormFields.field?(item) && !FormFields.form?(item)
          stack.concat(item.children)
          stack.concat(item.props.values)
        end
      end
      values
    end

    public

    def method_missing(name, *args, &block)
      return typed_data.public_send(name, *args, &block) if typed_data && typed_data.respond_to?(name)

      super
    end

    def respond_to_missing?(name, include_private = false)
      (typed_data && typed_data.respond_to?(name, include_private)) || super
    end
  end
end
