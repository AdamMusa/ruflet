# frozen_string_literal: true

begin
  require_relative "icons/material_icon_lookup"
  require_relative "icons/cupertino_icon_lookup"
rescue StandardError
  nil
end

module Ruflet
  class IconData
    attr_reader :value

    # The codepoint an icon prop sends for value, or nil for an unknown name.
    #
    # A name from Ruflet::MaterialIcons or Ruflet::CupertinoIcons carries its
    # set and is resolved in that table alone, so using one set never loads
    # the other's, and a name both sets define keeps the codepoint of the set
    # it was taken from. A plain string keeps the long-standing order:
    # Material first, Cupertino as the fallback.
    def self.codepoint_for(value)
      value = value.value if value.is_a?(IconData)
      case value
      when Ruflet::CupertinoIconName
        Ruflet::CupertinoIconLookup.codepoint_for(value)
      when Ruflet::MaterialIconName
        Ruflet::MaterialIconLookup.codepoint_for(value)
      else
        Ruflet::MaterialIconLookup.codepoint_for(value) ||
          Ruflet::CupertinoIconLookup.codepoint_for(value)
      end
    end

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
      return input if input.is_a?(Integer)
      # Already canonical, and it must keep the set it came from.
      return input if input.is_a?(Ruflet::MaterialIconName) || input.is_a?(Ruflet::CupertinoIconName)

      raw = input.to_s
      raw = raw.strip if raw.respond_to?(:strip)
      return raw if raw.empty?

      Ruflet::MaterialIconLookup.icon_name_for(raw) ||
        Ruflet::CupertinoIconLookup.icon_name_for(raw) ||
        raw
    end
  end
end
