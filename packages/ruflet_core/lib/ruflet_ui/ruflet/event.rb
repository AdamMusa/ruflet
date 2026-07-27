# frozen_string_literal: true

require "json"
require_relative "events/gesture_events"

module Ruflet
  class Event
    attr_reader :name, :target, :raw_data, :data, :typed_data, :page, :control

    def initialize(name:, target:, raw_data:, page:, control:)
      @name = name
      @target = target
      @raw_data = raw_data
      @data = parse_data(raw_data)
      @typed_data = Events::GestureEventFactory.build(name, @data)
      @page = page
      @control = control
    end

    # A stable convenience accessor shared by built-in and extension events.
    # Extension event names are intentionally not part of the core typed-event
    # registry, so fall back to the same value extraction used by GenericEvent.
    def value
      return typed_data.value if typed_data&.respond_to?(:value)

      Events::GenericEvent.from_data(data).value
    end

    private

    def parse_data(raw)
      return raw unless raw.is_a?(String)

      JSON.parse(raw)
    rescue JSON::ParserError
      raw
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
