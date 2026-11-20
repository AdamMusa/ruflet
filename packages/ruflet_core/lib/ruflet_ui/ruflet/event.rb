# frozen_string_literal: true

require "json"
require_relative "events/gesture_events"

module Ruflet
  class Event
    attr_reader :name, :target, :raw_data, :data, :typed_data, :page, :control

    # Choices whose declared value the renderer reads as a String and sends
    # back as the value of the control they belong to: wire type => the props
    # it reads, first one set wins (material_dropdown.dart: an option's key,
    # else its text; material_dropdown_m2.dart: then its wire id, "_i";
    # radio.dart: a radio's value).
    CHOICE_VALUE_PROPS = {
      "DropdownOption" => %w[key text _i],
      "Option" => %w[key text _i],
      "Radio" => %w[value]
    }.freeze

    # The controls whose value is one of those choices: a Dropdown's options
    # (select), the radios inside a RadioGroup (change).
    CHOICE_OWNERS = %w[Dropdown DropdownM2 RadioGroup].freeze

    # Events whose String payload is always the text the user typed, even
    # when it is not the control's value: material_search_bar.dart syncs the
    # text with its capitalization applied and sends it as typed; a
    # Dropdown's text_change is the text typed into it (synced as its text).
    TEXT_EVENTS = {
      "SearchBar" => %w[change submit],
      "Dropdown" => %w[text_change]
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
    # JSON is decoded too. The exception is what the user typed or picked:
    # the payload of a TEXT_EVENTS event, and a String that is the control's
    # own value, which the client syncs into the control (update_control)
    # right before the event that reports it (TextField and CodeEditor
    # change, TextField submit, Dropdown select, RadioGroup change). It stays
    # a String, even when it looks like JSON ("123", "2.50", "null", "[1]").
    # One case keeps the decoded value: the renderer sends an Integer option
    # key or radio value back as "2", and the handler still gets 2.
    def parse_data(raw)
      return raw unless raw.is_a?(String)

      decoded = decode_json(raw)
      return decoded if decoded.equal?(raw)
      return raw if text_event?

      props = @control.respond_to?(:props) ? @control.props : nil
      return decoded unless props.is_a?(Hash) && props["value"] == raw

      declared_choice?(decoded) ? decoded : raw
    end

    def decode_json(raw)
      return raw unless Object.const_defined?(:JSON)

      Object.const_get(:JSON).parse(raw)
    rescue StandardError
      raw
    end

    def text_event?
      return false unless @control.respond_to?(:wire_type)

      names = TEXT_EVENTS[@control.wire_type]
      !names.nil? && names.include?(@name.to_s)
    end

    # Whether +decoded+ (not a String) is a value the app declared on one of
    # the choices of a control that owns choices. When choices declare both
    # 2 and "2", the client sends "2" for either one, and the handler gets 2
    # as before.
    def declared_choice?(decoded)
      return false if decoded.nil? || decoded.is_a?(String) || decoded.is_a?(Hash) || decoded.is_a?(Array)
      return false unless @control.respond_to?(:wire_type) && CHOICE_OWNERS.include?(@control.wire_type)

      choice_values.include?(decoded)
    end

    # The declared values of the control's choices: its options, or the
    # radios inside a RadioGroup. radio_group.dart wraps its content in a
    # RadioGroup<String>, which every Radio below it joins, also one inside
    # a Form or a field's label or suffix. Only a nested RadioGroup owns the
    # radios inside it, and a nested Dropdown its options.
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
          names.each { |prop| value = (prop == "_i" ? item.wire_id : item.props[prop]) if value.nil? }
          values << value unless value.nil?
        elsif item.wire_type != "RadioGroup"
          owner = CHOICE_OWNERS.include?(item.wire_type)
          stack.concat(item.children)
          item.props.each { |prop, held| stack << held unless owner && prop == "options" }
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
