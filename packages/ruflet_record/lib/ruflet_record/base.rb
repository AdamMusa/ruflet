# frozen_string_literal: true

module RufletRecord
  class Base
    @abstract_class = true
    @descendants = []

    class << self
      attr_writer :connection, :table_name, :primary_key
      attr_accessor :abstract_class

      def inherited(subclass)
        super
        Base.descendants << subclass
        subclass.instance_variable_set(:@connection, @connection)
        subclass.instance_variable_set(:@primary_key, @primary_key || "id")
        subclass.instance_variable_set(:@validators, validators.dup)
        subclass.instance_variable_set(:@abstract_class, false)
      end

      def descendants
        @descendants ||= []
      end

      def establish_connection(config)
        @connection = Adapters::SQLiteAdapter.new(config)
        RufletRecord.connection = @connection if self == Base
        reset_column_information
        @connection
      end

      def connection
        @connection || RufletRecord.connection
      end

      def table_name
        @table_name ||= Inflector.pluralize(Inflector.underscore(name.to_s.split("::").last))
      end

      def primary_key
        @primary_key ||= "id"
      end

      def columns
        @columns ||= connection.columns(table_name)
      end

      def columns_hash
        @columns_hash ||= begin
          result = {}
          columns.each { |column| result[column.name] = column }
          result
        end
      end

      def column_names
        columns.map(&:name)
      end

      def reset_column_information
        @columns = nil
        @columns_hash = nil
      end

      def instantiate(row)
        record = allocate
        record.send(:initialize_from_database, row)
        record
      end

      def all
        Relation.new(self)
      end

      def where(conditions = nil, *binds); all.where(conditions, *binds); end
      def order(*values); all.order(*values); end
      def reorder(*values); all.reorder(*values); end
      def limit(value); all.limit(value); end
      def offset(value); all.offset(value); end
      def select(*values); all.select(*values); end
      def distinct(value = true); all.distinct(value); end
      def joins(value); all.joins(value); end
      def find(id); all.find(id); end
      def find_by(conditions); all.find_by(conditions); end
      def find_by!(conditions); all.find_by!(conditions); end
      def first(count = nil); all.first(count); end
      def last(count = nil); all.last(count); end
      def count(column = nil); all.count(column); end
      def sum(column); all.sum(column); end
      def average(column); all.average(column); end
      def minimum(column); all.minimum(column); end
      def maximum(column); all.maximum(column); end
      def exists?(conditions = nil); all.exists?(conditions); end
      def pluck(*columns); all.pluck(*columns); end
      def pick(*columns); all.pick(*columns); end
      def ids; all.ids; end
      def find_each(batch_size: 1000, &block); all.find_each(batch_size: batch_size, &block); end

      def create(attributes = {})
        record = new(attributes)
        record.save
        record
      end

      def create!(attributes = {})
        record = new(attributes)
        record.save!
        record
      end

      def find_or_initialize_by(attributes)
        find_by(attributes) || new(attributes)
      end

      def find_or_create_by(attributes)
        find_by(attributes) || create(attributes)
      end

      def find_or_create_by!(attributes)
        find_by(attributes) || create!(attributes)
      end

      def transaction(&block)
        connection.transaction(&block)
      end

      def delete_all
        all.delete_all
      end

      def destroy_all
        all.destroy_all
      end

      def scope(name, callable = nil, &block)
        body = callable || block
        raise ArgumentError, "scope requires a callable" unless body
        define_singleton_method(name) do |*args|
          value = body.call(*args)
          value.is_a?(Relation) ? value : all
        end
      end

      def validators
        @validators ||= []
      end

      def validates_presence_of(*attributes)
        attributes.each { |attribute| validators << [:presence, attribute.to_s, {}] }
      end

      def validates_uniqueness_of(*attributes)
        options = attributes.last.is_a?(Hash) ? attributes.pop : {}
        attributes.each { |attribute| validators << [:uniqueness, attribute.to_s, options] }
      end

      def belongs_to(name, options = {})
        class_name = options[:class_name] || Inflector.classify(name)
        foreign_key = (options[:foreign_key] || "#{name}_id").to_s
        define_method(name) do
          identifier = read_attribute(foreign_key)
          identifier.nil? ? nil : Inflector.constantize(class_name).find_by(Inflector.constantize(class_name).primary_key => identifier)
        end
        define_method("#{name}=") do |record|
          write_attribute(foreign_key, record && record.public_send(record.class.primary_key))
          instance_variable_set("@#{name}", record)
        end
      end

      def has_many(name, options = {})
        class_name = options[:class_name] || Inflector.classify(name)
        configured_foreign_key = options[:foreign_key]
        define_method(name) do
          klass = Inflector.constantize(class_name)
          owner_name = Inflector.underscore(self.class.name.to_s.split("::").last)
          foreign_key = (configured_foreign_key || "#{owner_name}_id").to_s
          klass.where(foreign_key => public_send(self.class.primary_key))
        end
      end

      def has_one(name, options = {})
        class_name = options[:class_name] || Inflector.classify(name)
        configured_foreign_key = options[:foreign_key]
        define_method(name) do
          owner_name = Inflector.underscore(self.class.name.to_s.split("::").last)
          foreign_key = (configured_foreign_key || "#{owner_name}_id").to_s
          Inflector.constantize(class_name).find_by(foreign_key => public_send(self.class.primary_key))
        end
      end
    end

    attr_reader :errors

    def initialize(attributes = {})
      @attributes = {}
      @original_attributes = {}
      @new_record = true
      @destroyed = false
      @errors = Errors.new
      self.class.columns.each do |column|
        @attributes[column.name] = cast_default(column)
      end
      assign_attributes(attributes)
    end

    def attributes
      @attributes.dup
    end

    def assign_attributes(values)
      values.each { |name, value| write_attribute(name, value) }
      self
    end

    def read_attribute(name)
      @attributes[name.to_s]
    end
    alias [] read_attribute

    def write_attribute(name, value)
      key = name.to_s
      column = self.class.columns_hash[key]
      raise UnknownAttributeError, "unknown attribute '#{key}' for #{self.class.name}" unless column
      @attributes[key] = column.cast(value)
    end

    def []=(name, value)
      write_attribute(name, value)
    end

    def method_missing(name, *args)
      value = name.to_s
      if value.end_with?("=") && args.length == 1
        attribute = value[0...-1]
        return write_attribute(attribute, args.first) if self.class.columns_hash.key?(attribute)
      elsif args.empty? && self.class.columns_hash.key?(value)
        return read_attribute(value)
      end
      super
    end

    def respond_to_missing?(name, include_private = false)
      value = name.to_s
      attribute = value.end_with?("=") ? value[0...-1] : value
      self.class.columns_hash.key?(attribute) || super
    end

    def new_record?
      @new_record
    end

    def persisted?
      !@new_record && !@destroyed
    end

    def destroyed?
      @destroyed
    end

    def changed?
      @attributes != @original_attributes
    end

    def changes
      result = {}
      @attributes.each do |name, value|
        original = @original_attributes[name]
        result[name] = [original, value] unless original == value
      end
      result
    end

    def valid?
      @errors.clear
      self.class.validators.each do |kind, attribute, options|
        value = read_attribute(attribute)
        if kind == :presence
          @errors.add(attribute, "can't be blank") if value.nil? || (value.respond_to?(:empty?) && value.empty?)
        elsif kind == :uniqueness && !value.nil?
          relation = self.class.where(attribute => value)
          relation = relation.where.not(self.class.primary_key => read_attribute(self.class.primary_key)) if persisted?
          @errors.add(attribute, "has already been taken") if relation.exists?
        end
      end
      @errors.empty?
    end

    def save
      return false unless valid?
      save_without_validation
      true
    rescue StatementInvalid => error
      @errors.add(:base, error.message)
      false
    end

    def save!
      raise RecordInvalid, self unless valid?
      save_without_validation
      true
    rescue StatementInvalid => error
      raise RecordNotSaved, error.message
    end

    def update(attributes)
      assign_attributes(attributes)
      save
    end

    def update!(attributes)
      assign_attributes(attributes)
      save!
    end

    def destroy
      return self unless persisted?
      primary = self.class.primary_key
      self.class.where(primary => read_attribute(primary)).delete_all
      @destroyed = true
      self
    end

    def delete
      destroy
    end

    def update_columns(attributes)
      raise RecordNotSaved, "cannot update a new record" unless persisted?
      primary = self.class.primary_key
      values = {}
      attributes.each do |name, value|
        write_attribute(name, value)
        values[name.to_s] = read_attribute(name)
      end
      self.class.where(primary => read_attribute(primary)).update_all(values)
      @original_attributes = @attributes.dup
      true
    end

    def touch
      raise RecordNotSaved, "cannot touch a new record" unless persisted?
      return true unless @attributes.key?("updated_at")
      update_columns("updated_at" => Time.now.utc)
    end

    def reload
      primary = self.class.primary_key
      fresh = self.class.find(read_attribute(primary))
      initialize_from_database(fresh.attributes)
      self
    end

    def ==(other)
      return true if equal?(other)
      return false unless other.is_a?(self.class)
      primary = self.class.primary_key
      persisted? && other.persisted? && read_attribute(primary) == other.read_attribute(primary)
    end

    private

    def initialize_from_database(row)
      @attributes = {}
      self.class.columns.each do |column|
        @attributes[column.name] = column.cast(row[column.name])
      end
      @original_attributes = @attributes.dup
      @new_record = false
      @destroyed = false
      @errors = Errors.new
      self
    end

    def save_without_validation
      touch_timestamps
      new_record? ? create_record : update_record
      @original_attributes = @attributes.dup
    end

    def create_record
      primary = self.class.primary_key
      values = @attributes.reject { |name, value| name == primary && value.nil? }
      sql, binds = SQL.insert(self.class.table_name, values)
      identifier = self.class.connection.insert(sql, binds)
      @attributes[primary] = identifier if @attributes.key?(primary) && @attributes[primary].nil?
      @new_record = false
    end

    def update_record
      primary = self.class.primary_key
      changed = changes
      changed.delete(primary)
      return if changed.empty?
      attributes = {}
      changed.each { |name, pair| attributes[name] = pair.last }
      relation = self.class.where(primary => read_attribute(primary))
      relation.update_all(attributes)
    end

    def touch_timestamps
      now = Time.now.utc
      if @attributes.key?("updated_at")
        @attributes["updated_at"] = now
      end
      if new_record? && @attributes.key?("created_at") && @attributes["created_at"].nil?
        @attributes["created_at"] = now
      end
    end

    def cast_default(column)
      value = column.default
      return nil if value.nil?
      if value.length >= 2 && value[0, 1] == "'" && value[-1, 1] == "'"
        value = value[1...-1].gsub("''", "'")
      end
      column.cast(value)
    end
  end
end
