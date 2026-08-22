# frozen_string_literal: true

module RufletRecord
  module SQL
    class Literal
      attr_reader :sql

      def initialize(sql)
        @sql = sql.to_s.freeze
      end

      def to_s
        @sql
      end
    end

    class Fragment
      attr_reader :sql, :binds

      def initialize(sql, binds)
        @sql = sql.to_s.freeze
        @binds = binds.freeze
      end
    end

    class << self

    def quote_identifier(name)
      parts = name.to_s.split(".")
      parts.map { |part| "\"#{part.gsub('"', '""')}\"" }.join(".")
    end

    def column(table, name)
      return name.sql if name.is_a?(Literal)

      value = name.to_s
      value.include?(".") ? quote_identifier(value) : "#{quote_identifier(table)}.#{quote_identifier(value)}"
    end

    def columns(table, values)
      selected = values.nil? || values.empty? ? [Literal.new("#{quote_identifier(table)}.*")] : values
      selected.map { |value| column(table, value) }.join(", ")
    end

    def predicate(table, conditions, binds)
      if conditions.is_a?(Fragment)
        return conditions
      elsif conditions.is_a?(Hash)
        parts = []
        values = []
        conditions.each do |name, value|
          identifier = column(table, name)
          if value.nil?
            parts << "#{identifier} IS NULL"
          elsif value.is_a?(Array)
            if value.empty?
              parts << "1 = 0"
            else
              parts << "#{identifier} IN (#{(["?"] * value.length).join(', ')})"
              values.concat(value)
            end
          elsif value.is_a?(Range)
            if value.exclude_end?
              parts << "(#{identifier} >= ? AND #{identifier} < ?)"
            else
              parts << "#{identifier} BETWEEN ? AND ?"
            end
            values << value.begin << value.end
          else
            parts << "#{identifier} = ?"
            values << value
          end
        end
        return Fragment.new(parts.empty? ? "1 = 1" : parts.join(" AND "), values)
      elsif conditions.is_a?(String)
        expected = conditions.count("?")
        if expected != binds.length
          raise ArgumentError, "wrong number of bind values (#{binds.length} for #{expected})"
        end
        return Fragment.new(conditions, binds)
      end

      raise ArgumentError, "where conditions must be a Hash, String, or SQL fragment"
    end

    def negate(fragment)
      Fragment.new("NOT (#{fragment.sql})", fragment.binds)
    end

    def order(table, values)
      values.map do |value|
        if value.is_a?(Hash)
          value.map do |name, direction|
            normalized = direction.to_s.upcase
            raise ArgumentError, "invalid order direction: #{direction}" unless %w[ASC DESC].include?(normalized)
            "#{column(table, name)} #{normalized}"
          end.join(", ")
        elsif value.is_a?(Symbol)
          "#{column(table, value)} ASC"
        elsif value.is_a?(Literal)
          value.sql
        else
          parse_order_string(table, value.to_s)
        end
      end.join(", ")
    end

    def parse_order_string(table, value)
      value.split(",").map do |piece|
        match = /\A\s*([A-Za-z_][A-Za-z0-9_.]*)(?:\s+(ASC|DESC))?\s*\z/i.match(piece)
        raise ArgumentError, "unsafe order expression: #{value.inspect}" unless match
        direction = match[2] ? " #{match[2].upcase}" : " ASC"
        "#{column(table, match[1])}#{direction}"
      end.join(", ")
    end

    def select(table, values)
      sql = +"SELECT "
      sql << "DISTINCT " if values[:distinct]
      sql << columns(table, values[:select])
      sql << " FROM #{quote_identifier(table)}"
      sql << " #{values[:joins].join(' ')}" unless values[:joins].empty?
      binds = []
      append_wheres(sql, binds, values[:where])
      unless values[:order].empty?
        sql << " ORDER BY #{order(table, values[:order])}"
      end
      if values[:limit]
        sql << " LIMIT ?"
        binds << values[:limit]
      elsif values[:offset]
        sql << " LIMIT -1"
      end
      if values[:offset]
        sql << " OFFSET ?"
        binds << values[:offset]
      end
      [sql, binds]
    end

    def insert(table, attributes)
      names = attributes.keys
      sql = "INSERT INTO #{quote_identifier(table)}"
      if names.empty?
        return ["#{sql} DEFAULT VALUES", []]
      end
      quoted = names.map { |name| quote_identifier(name) }.join(", ")
      placeholders = (["?"] * names.length).join(", ")
      ["#{sql} (#{quoted}) VALUES (#{placeholders})", names.map { |name| attributes[name] }]
    end

    def update(table, attributes, wheres)
      assignments = attributes.keys.map { |name| "#{quote_identifier(name)} = ?" }.join(", ")
      binds = attributes.keys.map { |name| attributes[name] }
      sql = "UPDATE #{quote_identifier(table)} SET #{assignments}"
      append_wheres(sql, binds, wheres)
      [sql, binds]
    end

    def delete(table, wheres)
      sql = "DELETE FROM #{quote_identifier(table)}"
      binds = []
      append_wheres(sql, binds, wheres)
      [sql, binds]
    end

    def append_wheres(sql, binds, wheres)
      return if wheres.empty?

      sql << " WHERE #{wheres.map { |fragment| "(#{fragment.sql})" }.join(' AND ')}"
      wheres.each { |fragment| binds.concat(fragment.binds) }
    end
    end
  end
end
