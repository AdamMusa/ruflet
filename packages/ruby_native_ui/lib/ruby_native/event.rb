# frozen_string_literal: true

require "json"

module RubyNative
  class Event
    attr_reader :name, :target, :raw_data, :data, :page, :control

    def initialize(name:, target:, raw_data:, page:, control:)
      @name = name
      @target = target
      @raw_data = raw_data
      @data = parse_data(raw_data)
      @page = page
      @control = control
    end

    private

    def parse_data(raw)
      return raw unless raw.is_a?(String)

      JSON.parse(raw)
    rescue JSON::ParserError
      raw
    end
  end
end
