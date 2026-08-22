# frozen_string_literal: true

module RufletRecord
  class TableDefinition
    attr_reader :name, :columns, :indexes, :foreign_keys

    def initialize(name, id)
      @name = name.to_s
      @columns = []
      @indexes = []
      @foreign_keys = []
      integer(:id, primary_key: true, auto_increment: true, null: false) unless id == false
    end

    def column(name, type, options = {})
      @columns << [name.to_s, type.to_sym, options]
      self
    end

    def string(name, options = {}); column(name, :string, options); end
    def text(name, options = {}); column(name, :text, options); end
    def integer(name, options = {}); column(name, :integer, options); end
    def float(name, options = {}); column(name, :float, options); end
    def decimal(name, options = {}); column(name, :decimal, options); end
    def boolean(name, options = {}); column(name, :boolean, options); end
    def datetime(name, options = {}); column(name, :datetime, options); end
    def date(name, options = {}); column(name, :date, options); end
    def binary(name, options = {}); column(name, :binary, options); end
    def json(name, options = {}); column(name, :json, options); end

    def references(name, options = {})
      column_options = options.dup
      foreign_key = column_options.delete(:foreign_key)
      index_option = column_options.delete(:index)
      column_name = "#{name}_id"
      column(column_name, :integer, column_options)
      index(column_name, index_option.is_a?(Hash) ? index_option : {}) unless index_option == false
      add_foreign_key(column_name, name, foreign_key) if foreign_key
    end
    alias belongs_to references

    def timestamps(options = {})
      datetime(:created_at, options)
      datetime(:updated_at, options)
    end

    def index(columns, options = {})
      @indexes << [Array(columns).map(&:to_s), options]
      self
    end

    def add_foreign_key(column_name, reference_name, options)
      settings = options.is_a?(Hash) ? options : {}
      target_table = settings[:to_table] || Inflector.pluralize(reference_name.to_s)
      target_column = settings[:primary_key] || "id"
      @foreign_keys << [
        column_name.to_s,
        target_table.to_s,
        target_column.to_s,
        settings[:on_delete],
        settings[:on_update]
      ]
      self
    end
  end

  class Schema
    TYPE_SQL = {
      string: "VARCHAR", text: "TEXT", integer: "INTEGER", float: "REAL",
      decimal: "DECIMAL", boolean: "BOOLEAN", datetime: "DATETIME",
      date: "DATE", binary: "BLOB", json: "TEXT"
    }.freeze

    class << self
      attr_writer :connection

      def connection
        @connection || RufletRecord.connection
      end

      def define(&block)
        schema = new(connection)
        schema.instance_eval(&block)
        schema
      end
    end

    def initialize(connection = nil)
      @connection = connection || RufletRecord.connection
    end

    def create_table(name, options = {}, &block)
      definition = TableDefinition.new(name, options.fetch(:id, true))
      block.call(definition) if block
      if options[:force]
        drop_table(name, if_exists: true)
      elsif options[:if_not_exists] && @connection.table_exists?(name)
        return
      end
      columns = definition.columns.map { |column| column_sql(*column) }
      definition.foreign_keys.each { |foreign_key| columns << foreign_key_sql(*foreign_key) }
      @connection.execute("CREATE TABLE #{SQL.quote_identifier(name)} (#{columns.join(', ')})")
      definition.indexes.each { |columns_value, index_options| add_index(name, columns_value, index_options) }
      reset_models
    end

    def drop_table(name, options = {})
      clause = options[:if_exists] ? " IF EXISTS" : ""
      @connection.execute("DROP TABLE#{clause} #{SQL.quote_identifier(name)}")
      reset_models
    end

    def add_column(table, name, type, options = {})
      @connection.execute("ALTER TABLE #{SQL.quote_identifier(table)} ADD COLUMN #{column_sql(name, type, options)}")
      reset_models
    end

    def add_index(table, columns, options = {})
      names = Array(columns).map(&:to_s)
      index_name = options[:name] || "index_#{table}_on_#{names.join('_and_')}"
      unique = options[:unique] ? "UNIQUE " : ""
      quoted_columns = names.map { |name| SQL.quote_identifier(name) }.join(", ")
      @connection.execute("CREATE #{unique}INDEX #{SQL.quote_identifier(index_name)} ON #{SQL.quote_identifier(table)} (#{quoted_columns})")
    end

    def remove_index(table, columns = nil, options = {})
      names = Array(columns).map(&:to_s)
      index_name = options[:name] || "index_#{table}_on_#{names.join('_and_')}"
      @connection.execute("DROP INDEX #{SQL.quote_identifier(index_name)}")
    end

    def rename_table(old_name, new_name)
      @connection.execute("ALTER TABLE #{SQL.quote_identifier(old_name)} RENAME TO #{SQL.quote_identifier(new_name)}")
      reset_models
    end

    private

    def column_sql(name, type, options)
      sql_type = TYPE_SQL[type.to_sym]
      raise ArgumentError, "unknown column type: #{type}" unless sql_type
      sql = "#{SQL.quote_identifier(name)} #{sql_type}"
      if options[:primary_key]
        sql << " PRIMARY KEY"
        sql << " AUTOINCREMENT" if options[:auto_increment]
      end
      sql << " NOT NULL" if options[:null] == false
      sql << " UNIQUE" if options[:unique]
      sql << " DEFAULT #{quote_default(options[:default])}" if options.key?(:default)
      sql
    end

    def quote_default(value)
      return "NULL" if value.nil?
      return value.to_s if value.is_a?(Numeric)
      return value ? "1" : "0" if value == true || value == false
      return value.sql if value.is_a?(SQL::Literal)

      "'#{value.to_s.gsub("'", "''")}'"
    end

    def foreign_key_sql(column, target_table, target_column, on_delete, on_update)
      sql = "FOREIGN KEY (#{SQL.quote_identifier(column)}) REFERENCES #{SQL.quote_identifier(target_table)} (#{SQL.quote_identifier(target_column)})"
      sql << " ON DELETE #{foreign_key_action(on_delete)}" if on_delete
      sql << " ON UPDATE #{foreign_key_action(on_update)}" if on_update
      sql
    end

    def foreign_key_action(value)
      action = value.to_s.upcase.tr("_", " ")
      allowed = ["CASCADE", "RESTRICT", "SET NULL", "SET DEFAULT", "NO ACTION"]
      raise ArgumentError, "invalid foreign key action: #{value}" unless allowed.include?(action)
      action
    end

    def reset_models
      Base.descendants.each(&:reset_column_information) if RufletRecord.const_defined?(:Base)
    end
  end

  class Migration
    class << self
      attr_accessor :connection

      def migrate(direction = :up)
        migration = new
        if migration.respond_to?(direction)
          migration.public_send(direction)
        elsif direction.to_sym == :up && migration.respond_to?(:change)
          migration.change
        else
          raise Error, "migration does not implement #{direction}"
        end
      end
    end

    def connection
      self.class.connection || RufletRecord.connection
    end

    def method_missing(name, *args, &block)
      schema = Schema.new(connection)
      return schema.public_send(name, *args, &block) if schema.respond_to?(name)
      super
    end

    def respond_to_missing?(name, include_private = false)
      Schema.new(connection).respond_to?(name, include_private) || super
    end
  end
end
