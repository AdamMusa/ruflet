# frozen_string_literal: true

# Set itself is provided natively by mruby-set; this adds the Enumerable
# integration the CRuby set library ships.
raise LoadError, "this VM build does not include mruby-set" unless Object.const_defined?(:Set)

module Enumerable
  unless method_defined?(:to_set)
    def to_set
      set = Set.new
      each { |value| set.add(value) }
      set
    end
  end
end

class Array
  unless method_defined?(:to_set)
    def to_set
      set = Set.new
      each { |value| set.add(value) }
      set
    end
  end
end
