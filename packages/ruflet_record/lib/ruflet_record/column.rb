# frozen_string_literal: true

unless RUBY_ENGINE == "mruby"
  begin
    require "json"
  rescue LoadError
    nil
  end
end

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
      return :json if value.include?("JSON")
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
      when :json
        cast_json(value)
      else
        value
      end
    end

    # The JSON text a Hash or Array is bound as (see SQLiteAdapter).
    def self.dump_json(value)
      unless Object.const_defined?(:JSON)
        raise ArgumentError, "a json column needs the JSON library to store #{value.class}"
      end

      Object.const_get(:JSON).generate(value)
    end

    private

    # A json column's value as Ruby data: text read from the database is
    # parsed; what the application assigned is kept as given.
    def cast_json(value)
      return value unless value.is_a?(String) && Object.const_defined?(:JSON)

      Object.const_get(:JSON).parse(value)
    rescue StandardError
      value
    end

    # Datetimes are stored as UTC wall-clock text, so every Time is kept as
    # the same instant in UTC: a local Time (Time.now) or a string with an
    # offset ("...+02:00", "...Z") must not be read back hours off.
    def cast_time(value)
      return value.getutc if value.is_a?(Time)
      match = /\A(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}):(\d{2})(?:\.\d+)? *(Z|[+-]\d{2}:?\d{2})?)?/.match(value.to_s)
      return value unless match

      time = Time.utc(
        match[1].to_i, match[2].to_i, match[3].to_i,
        (match[4] || "0").to_i, (match[5] || "0").to_i,
        (match[6] || "0").to_i
      )
      time - utc_offset_seconds(match[7])
    rescue StandardError
      value
    end

    def utc_offset_seconds(zone)
      return 0 if zone.nil? || zone == "Z"

      digits = zone.delete(":")
      seconds = (digits[1, 2].to_i * 3600) + (digits[3, 2].to_i * 60)
      zone[0, 1] == "-" ? -seconds : seconds
    end
  end
end
