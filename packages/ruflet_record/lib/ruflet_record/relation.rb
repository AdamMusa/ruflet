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
      sql, binds = bound_sql_and_binds
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

    # The last record, or the last +count+, in the relation's order (by
    # primary key when it has none). With a limit or offset they are the last
    # of the rows the relation selects.
    def last(count = nil)
      count = count.to_i unless count.nil?
      return last_selected(count) if row_window?

      order = @values[:order].empty? ? [{ @model.primary_key => :desc }] : reversed_order
      return last_by_position(count) unless order

      relation = reorder(*order)
      count ? relation.limit(count).to_a.reverse : relation.limit(1).to_a.first
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

    # With a limit, offset or distinct this counts from a subquery of the
    # rows the relation selects, as Active Record does: the rows, or the
    # non-NULL values of +column+ in them. A distinct relation with one
    # selected column counts that column's distinct values, NULL excluded,
    # also as Active Record does.
    def count(column = nil)
      unless row_window? || @values[:distinct]
        return aggregate("COUNT", column || SQL::Literal.new("*"), integer: true)
      end

      selected = @values[:select]
      if column.nil? && @values[:distinct] && selected.length == 1 && !selected.first.is_a?(SQL::Literal)
        column = selected.first
      end
      column = nil if column.is_a?(SQL::Literal) && column.sql.strip == "*"
      return row_count if column.nil?

      counted = select(SQL::Literal.new("#{SQL.column(@table_name, column)} AS \"count_column\""))
      counted = counted.reorder unless row_window?
      count_from(counted, "COUNT(\"subquery\".\"count_column\")")
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
      sql, binds = SQL.update(@table_name, SQL.column_values(stringify_keys(attributes)), write_wheres)
      @model.connection.update(sql, binds)
    end

    def delete_all
      sql, binds = SQL.delete(@table_name, write_wheres)
      @model.connection.delete(sql, binds)
    end

    def destroy_all
      to_a.each(&:destroy)
    end

    # Visits the records in primary key order, batch_size at a time, and
    # stops after the relation's limit when it has one.
    def find_each(batch_size: 1000)
      return to_enum(:find_each, batch_size: batch_size) unless block_given?
      remaining = @values[:limit]
      cursor = nil
      loop do
        size = remaining && remaining < batch_size.to_i ? remaining : batch_size
        relation = reorder(@model.primary_key => :asc).limit(size)
        relation = relation.where("#{SQL.column(@table_name, @model.primary_key)} > ?", cursor) if cursor
        batch = relation.to_a
        break if batch.empty?
        batch.each { |record| yield record }
        if remaining
          remaining -= batch.length
          break if remaining <= 0
        end
        cursor = batch.last.public_send(@model.primary_key)
      end
    end

    # A model's scopes chain on its relations (User.where(...).active): the
    # scope's relation is merged into this one. Other class methods are not
    # delegated, because they would run without this relation's conditions.
    # Public, as Base#method_missing is: mruby does not dispatch to a private
    # method_missing for a call with a receiver.
    def method_missing(name, *args, &block)
      return super unless @model.send(:scope_defined?, name)

      value = @model.public_send(name, *args, &block)
      return value unless value.is_a?(Relation)

      # A parent model's scope builds the parent's relation. Over the same
      # table it applies to this model's.
      if !value.model.equal?(@model) && @model.ancestors.include?(value.model) && value.table_name == @table_name
        value = Relation.new(@model, value.send(:values))
      end
      merge(value)
    end

    def respond_to_missing?(name, include_private = false)
      @model.send(:scope_defined?, name) || super
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
      sql, binds = bound_sql_and_binds
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

    # Whether a limit or offset narrows the rows the relation selects.
    def row_window?
      !@values[:limit].nil? || !@values[:offset].nil?
    end

    # The number of rows the relation selects.
    def row_count
      counted = @values[:distinct] ? self : select(SQL::Literal.new("1"))
      counted = counted.reorder unless row_window?
      count_from(counted, "COUNT(*)")
    end

    def count_from(relation, expression)
      sql, binds = relation.send(:bound_sql_and_binds)
      row = @model.connection.select_all("SELECT #{expression} AS value FROM (#{sql}) AS \"subquery\"", binds).first
      row ? row["value"].to_i : 0
    end

    # The conditions an UPDATE or DELETE runs with. With a limit or offset
    # they pick the rows the relation selects by primary key, as Active
    # Record does on SQLite; otherwise they are the relation's conditions.
    def write_wheres
      return bound_wheres unless row_window?

      sql, binds = select(@model.primary_key).distinct(false).send(:bound_sql_and_binds)
      [SQL::Fragment.new("#{SQL.column(@table_name, @model.primary_key)} IN (#{sql})", binds)]
    end

    def last_selected(count)
      relation = @values[:order].empty? ? reorder(@model.primary_key => :asc) : self
      records = relation.to_a
      count ? records.last(count) : records.last
    end

    # An order given as SQL cannot be reversed safely, so the last rows are
    # read by their position in it.
    def last_by_position(count)
      wanted = count || 1
      start = row_count - wanted
      records = offset(start > 0 ? start : 0).limit(wanted).to_a
      count ? records : records.last
    end

    # The relation's order reversed, or nil when part of it is SQL.
    def reversed_order
      reversed = []
      @values[:order].each do |value|
        if value.is_a?(Hash)
          flipped = {}
          value.each { |name, direction| flipped[name] = direction.to_s.upcase == "DESC" ? :asc : :desc }
          reversed << flipped
        elsif value.is_a?(Symbol)
          reversed << { value => :desc }
        elsif value.is_a?(SQL::Literal)
          return nil
        else
          pieces = SQL.parse_order_string(@table_name, value.to_s).split(", ").map do |piece|
            piece.end_with?(" DESC") ? "#{piece[0...-5]} ASC" : "#{piece[0...-4]} DESC"
          end
          reversed << SQL::Literal.new(pieces.join(", "))
        end
      end
      reversed
    end

    def to_sql_and_binds
      SQL.select(@table_name, @values)
    end

    # What a query runs with. bound_attributes keeps the values as given.
    def bound_sql_and_binds
      SQL.select(@table_name, @values.merge(where: bound_wheres))
    end

    def bound_wheres
      @values[:where].map { |fragment| SQL.bound_fragment(fragment) }
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
