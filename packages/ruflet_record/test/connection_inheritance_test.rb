# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

# A subclass copied its parent's connection when it was defined, so a model
# defined before ApplicationRecord.establish_connection (models first, then
# the connection) had none and raised ConnectionNotEstablished, or used
# RufletRecord.connection instead of its parent's database.
class ConnectionInheritanceTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @connections = []
    @application = Class.new(RufletRecord::Base) { self.abstract_class = true }
    @model = Class.new(@application) { self.table_name = "items" }
  end

  def teardown
    @connections.each(&:close)
    FileUtils.rm_rf(@dir)
  end

  def test_a_model_uses_the_connection_its_parent_establishes_later
    connection = connect(@application, "app")
    RufletRecord::Schema.new(connection).create_table(:items) { |table| table.string :name }

    assert_same connection, @model.connection
    @model.create!(name: "first")
    assert_equal ["first"], @model.pluck(:name)
  end

  def test_a_model_can_still_have_its_own_connection
    connect(@application, "app")
    own = connect(@model, "own")

    assert_same own, @model.connection
    refute_same own, @application.connection
  end

  # As before: a model defined after its parent connected keeps that
  # connection when the parent reconnects.
  def test_a_model_defined_after_the_parent_connected_keeps_that_connection
    first = connect(@application, "first")
    first.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name VARCHAR, extra VARCHAR)")
    later = Class.new(@application) { self.table_name = "items" }
    later.create!(name: "one", extra: "e")

    second = connect(@application, "second")
    second.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name VARCHAR)")

    assert_same first, later.connection
    later.create!(name: "two", extra: "f")
    assert_equal %w[one two], later.pluck(:name)
  end

  # A model that follows its parent's connection reads its columns again
  # when the parent reconnects.
  def test_a_following_model_forgets_the_previous_databases_columns
    connect(@application, "first").execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name VARCHAR, extra VARCHAR)")
    @model.create!(name: "one", extra: "e")

    second = connect(@application, "second")
    second.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name VARCHAR)")

    assert_same second, @model.connection
    @model.create!(name: "two")
    assert_equal %w[id name], @model.column_names
  end

  # As before: Base's direct subclasses without a connection of their own use
  # RufletRecord.connection, even after Base.establish_connection.
  def test_a_direct_subclass_of_base_uses_the_global_connection
    direct = Class.new(RufletRecord::Base) { self.table_name = "items" }
    previous_global = RufletRecord.instance_variable_get(:@connection)
    previous_base = RufletRecord::Base.instance_variable_get(:@connection)
    base = connect(RufletRecord::Base, "base")
    global = RufletRecord::Adapters::SQLiteAdapter.new(database: File.join(@dir, "global.sqlite3"))
    @connections << global
    RufletRecord.connection = global

    assert_same base, RufletRecord::Base.connection
    assert_same global, direct.connection
  ensure
    RufletRecord::Base.instance_variable_set(:@connection, previous_base)
    RufletRecord.connection = previous_global
  end

  private

  def connect(model, name)
    connection = model.establish_connection(database: File.join(@dir, "#{name}.sqlite3"))
    @connections << connection
    connection
  end
end
