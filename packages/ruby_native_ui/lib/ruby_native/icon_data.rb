# frozen_string_literal: true

require_relative "icons/material_icon_lookup"
require_relative "icons/cupertino_icon_lookup"

module RubyNative
  class IconData
    attr_reader :value

    def initialize(value)
      @value = normalize(value)
    end

    def ==(other)
      other_value = other.is_a?(IconData) ? other.value : self.class.new(other).value
      if value.is_a?(Integer) && other_value.is_a?(Integer)
        value == other_value
      elsif value.is_a?(String) && other_value.is_a?(String)
        value.casecmp?(other_value)
      else
        value == other_value
      end
    end

    def eql?(other)
      self == other
    end

    def hash
      value.is_a?(String) ? value.downcase.hash : value.hash
    end

    def to_s
      value.to_s
    end

    private

    def normalize(input)
      return input.value if input.is_a?(IconData)
      if input.is_a?(Integer)
        codepoint = RubyNative::MaterialIconLookup.codepoint_for(input)
        codepoint = RubyNative::CupertinoIconLookup.codepoint_for(input) if codepoint == input
        return codepoint
      end

      raw = input.to_s.strip
      return raw if raw.empty?

      codepoint = RubyNative::MaterialIconLookup.codepoint_for(raw)
      codepoint = RubyNative::CupertinoIconLookup.codepoint_for(raw) if codepoint.nil?
      return codepoint unless codepoint.nil?

      raw
    end
  end
end
