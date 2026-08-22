# frozen_string_literal: true

module RufletRecord
  class WhereChain
    def initialize(relation)
      @relation = relation
    end

    def not(conditions, *binds)
      fragment = SQL.predicate(@relation.table_name, conditions, binds)
      @relation.add_where(SQL.negate(fragment))
    end
  end

  class Relation
    include Enumerable

    attr_reader :model, :table_name

    def initialize(model, values = nil)
      @model = model
      @table_name = model.table_name
      @values = values || {
        where: [], order: [], select: [], joins: [], limit: nil,
        offset: nil, distinct: false
      }
      @loaded = false
      @records = nil
    end

    def where(conditions = nil, *binds)
      return WhereChain.new(self) if conditions.nil?
      add_where(SQL.predicate(@table_name, conditions, binds))
    end

    def add_where(fragment)
      spawn_with(:where, @values[:where] + [fragment])
    end

    def order(*values)
      additions = values.flatten
      SQL.order(@table_name, additions)
      spawn_with(:order, @values[:order] + additions)
    end

    def reorder(*values)
      replacements = values.flatten
      SQL.order(@table_name, replacements)
      spawn_with(:order, replacements)
    end

    def limit(value)
      number = value.nil? ? nil : value.to_i
      raise ArgumentError, "limit must not be negative" if number && number < 0
      spawn_with(:limit, number)
    end

    def offset(value)
      number = value.nil? ? nil : value.to_i
      raise ArgumentError, "offset must not be negative" if number && number < 0
      spawn_with(:offset, number)
    end

    def select(*columns)
      spawn_with(:select, columns.flatten)
    end

    def distinct(value = true)
      spawn_with(:distinct, !!value)
    end

    def joins(sql)
      value = sql.is_a?(SQL::Literal) ? sql.sql : sql.to_s
      raise ArgumentError, "joins requires an explicit JOIN expression" unless value =~ /\A\s*(INNER|LEFT|RIGHT|CROSS)?\s*JOIN\s+/i
      spawn_with(:joins, @values[:joins] + [value])
    end

    def merge(other)
      raise ArgumentError, "relations must have the same model" unless other.model == @model
      merged = duplicate_values
      other_values = other.send(:values)
      merged[:where] += other_values[:where]
      merged[:order] += other_values[:order]
      merged[:joins] += other_values[:joins]
      merged[:select] = other_values[:select] unless other_values[:select].empty?
      merged[:limit] = other_values[:limit] unless other_values[:limit].nil?
      merged[:offset] = other_values[:offset] unless other_values[:offset].nil?
      merged[:distinct] ||= other_values[:distinct]
      self.class.new(@model, merged)
    end

    def each(&block)
      return to_enum(:each) unless block
      to_a.each(&block)
    end

    def to_a
      load unless @loaded
      @records.dup
    end

    def load
      sql, binds = to_sql_and_binds
      @records = @model.connection.select_all(sql, binds).map { |row| @model.instantiate(row) }
      @loaded = true
      self
    end

    def loaded?
      @loaded
    end

    def reload
      @loaded = false
      @records = nil
      load
    end

    def first(count = nil)
      return limit(count).to_a if count
      limit(1).to_a.first
    end

    def last(count = nil)
      primary = @model.primary_key
      relation = reorder(primary => :desc)
      records = count ? relation.limit(count).to_a.reverse : relation.limit(1).to_a.first
      records
    end

    def find(id)
      record = where(@model.primary_key => id).first
      raise RecordNotFound, "Couldn't find #{@model.name} with '#{@model.primary_key}'=#{id}" unless record
      record
    end

    def find_by(conditions)
      where(conditions).first
    end

    def find_by!(conditions)
      record = find_by(conditions)
      raise RecordNotFound, "Couldn't find #{@model.name}" unless record
      record
    end

    def count(column = nil)
      aggregate("COUNT", column || SQL::Literal.new("*"), integer: true)
    end

    def sum(column)
      aggregate("SUM", column) || 0
    end

    def average(column)
      aggregate("AVG", column)
    end

    def minimum(column)
      aggregate("MIN", column)
    end

    def maximum(column)
      aggregate("MAX", column)
    end

    def exists?(conditions = nil)
      relation = conditions.nil? ? self : where(conditions)
      !relation.select(SQL::Literal.new("1")).limit(1).send(:pluck_value).nil?
    end

    def pluck(*columns)
      names = columns.flatten
      rows = select(*names).send(:raw_rows)
      return rows.map { |row| row[names.first.to_s] } if names.length == 1
      rows.map { |row| names.map { |name| row[name.to_s] } }
    end

    def pick(*columns)
      values = limit(1).pluck(*columns)
      values.first
    end

    def ids
      pluck(@model.primary_key)
    end

    def create(attributes = {})
      record = @model.new(scope_for_create.merge(attributes))
      record.save
      record
    end

    def create!(attributes = {})
      record = @model.new(scope_for_create.merge(attributes))
      record.save!
      record
    end

    def update_all(attributes)
      raise ArgumentError, "attributes must not be empty" if attributes.empty?
      sql, binds = SQL.update(@table_name, stringify_keys(attributes), @values[:where])
      @model.connection.update(sql, binds)
    end

    def delete_all
      sql, binds = SQL.delete(@table_name, @values[:where])
      @model.connection.delete(sql, binds)
    end

    def destroy_all
      to_a.each(&:destroy)
    end

    def find_each(batch_size: 1000)
      return to_enum(:find_each, batch_size: batch_size) unless block_given?
      cursor = nil
      loop do
        relation = reorder(@model.primary_key => :asc).limit(batch_size)
        relation = relation.where("#{SQL.column(@table_name, @model.primary_key)} > ?", cursor) if cursor
        batch = relation.to_a
        break if batch.empty?
        batch.each { |record| yield record }
        cursor = batch.last.public_send(@model.primary_key)
      end
    end

    def to_sql
      to_sql_and_binds.first
    end

    def bound_attributes
      to_sql_and_binds.last
    end

    protected

    attr_reader :values

    def raw_rows
      sql, binds = to_sql_and_binds
      @model.connection.select_all(sql, binds)
    end

    def pluck_value
      row = raw_rows.first
      row && row.values.first
    end

    private

    def aggregate(function, column, options = {})
      expression = column.is_a?(SQL::Literal) ? column.sql : SQL.column(@table_name, column)
      row = select(SQL::Literal.new("#{function}(#{expression}) AS value")).reorder.send(:raw_rows).first
      value = row && row["value"]
      options[:integer] && value ? value.to_i : value
    end

    def to_sql_and_binds
      SQL.select(@table_name, @values)
    end

    def spawn_with(key, value)
      values = duplicate_values
      values[key] = value
      self.class.new(@model, values)
    end

    def duplicate_values
      {
        where: @values[:where].dup, order: @values[:order].dup,
        select: @values[:select].dup, joins: @values[:joins].dup,
        limit: @values[:limit], offset: @values[:offset], distinct: @values[:distinct]
      }
    end

    def stringify_keys(attributes)
      result = {}
      attributes.each { |key, value| result[key.to_s] = value }
      result
    end

    def scope_for_create
      attributes = {}
      @values[:where].each do |fragment|
        next unless fragment.sql =~ /\A\"[^\"]+\"\.\"([^\"]+)\" = \?\z/
        attributes[Regexp.last_match(1)] = fragment.binds.first
      end
      attributes
    end
  end
end
