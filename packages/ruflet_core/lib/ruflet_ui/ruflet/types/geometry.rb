# frozen_string_literal: true

module Ruflet
  module UI
    module Types
      class Offset
        attr_reader :x, :y

        def initialize(x:, y:)
          @x = x
          @y = y
        end

        def self.from_wire(value)
          case value
          when Offset
            value
          when Array
            return nil unless value.size >= 2

            new(x: value[0], y: value[1])
          when Hash
            x = value["x"] || value[:x] || value[0]
            y = value["y"] || value[:y] || value[1]
            return nil if x.nil? || y.nil?

            new(x: x, y: y)
          else
            nil
          end
        end

        def to_h
          { "x" => x, "y" => y }
        end
      end

      class Duration
        attr_reader :milliseconds

        def initialize(milliseconds:)
          @milliseconds = milliseconds
        end

        def self.from_wire(value)
          return value if value.is_a?(Duration)
          return nil if value.nil?

          if value.is_a?(Hash)
            ms = value["milliseconds"] || value[:milliseconds] || value["ms"] || value[:ms]
            return nil if ms.nil?

            return new(milliseconds: ms)
          end

          new(milliseconds: value)
        end

        def to_h
          { "milliseconds" => milliseconds }
        end
      end
    end
  end
end
