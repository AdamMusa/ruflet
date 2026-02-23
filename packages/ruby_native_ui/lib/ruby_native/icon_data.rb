# frozen_string_literal: true

module RubyNative
  class IconData
    attr_reader :value

    def initialize(value)
      @value = value.to_s
    end

    def ==(other)
      other_value =
        case other
        when IconData
          other.value
        else
          other.to_s
        end
      value.casecmp?(other_value)
    end

    def eql?(other)
      self == other
    end

    def hash
      value.downcase.hash
    end

    def to_s
      value
    end
  end
end
