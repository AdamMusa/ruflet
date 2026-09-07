# frozen_string_literal: true

unless RUBY_ENGINE == "mruby"
  require_relative "ruflet_record/version"
  require_relative "ruflet_record/errors"
  require_relative "ruflet_record/inflector"
  require_relative "ruflet_record/sql"
  require_relative "ruflet_record/column"
  require_relative "ruflet_record/adapters/sqlite_adapter"
  require_relative "ruflet_record/schema"
  require_relative "ruflet_record/relation"
  require_relative "ruflet_record/base"
end

module RufletRecord
  class << self
    attr_writer :connection

    def connection
      @connection || raise(ConnectionNotEstablished, "No RufletRecord database connection")
    end

    def establish_connection(config)
      self.connection = Adapters::SQLiteAdapter.new(config)
    end

    def sql(value)
      SQL::Literal.new(value)
    end
  end
end

if RUBY_ENGINE == "mruby" && $LOADED_FEATURES
  $LOADED_FEATURES << "ruflet_record" unless $LOADED_FEATURES.include?("ruflet_record")
  $LOADED_FEATURES << "/__preloaded_gems__/ruflet_record.rb" unless $LOADED_FEATURES.include?("/__preloaded_gems__/ruflet_record.rb")
end
