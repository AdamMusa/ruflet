# frozen_string_literal: true

module RufletRecord
  class Column
    attr_reader :name, :sql_type, :default

    def initialize(name, sql_type, null, default, primary)
      @name = name.to_s.freeze
      @sql_type = sql_type.to_s.freeze
      @null = null
      @default = default
      @primary = primary
    end

    def null?
      @null
    end

    def primary?
      @primary
    end

    def type
      value = @sql_type.upcase
      return :boolean if value.include?("BOOL")
      return :integer if value.include?("INT")
      return :float if value.include?("REAL") || value.include?("FLOA") || value.include?("DOUB")
      return :decimal if value.include?("DEC") || value.include?("NUM")
      return :datetime if value.include?("DATE") || value.include?("TIME")
      return :binary if value.include?("BLOB")

      :string
    end

    def cast(value)
      return nil if value.nil?

      case type
      when :boolean
        value == true || value.to_s == "1" || value.to_s.downcase == "true"
      when :integer
        value.to_i
      when :float, :decimal
        value.to_f
      when :datetime
        cast_time(value)
      else
        value
      end
    end

    private

    def cast_time(value)
      return value if value.is_a?(Time)
      match = /\A(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}):(\d{2}))?/.match(value.to_s)
      return value unless match

      Time.utc(
        match[1].to_i, match[2].to_i, match[3].to_i,
        (match[4] || "0").to_i, (match[5] || "0").to_i,
        (match[6] || "0").to_i
      )
    rescue StandardError
      value
    end
  end
end
