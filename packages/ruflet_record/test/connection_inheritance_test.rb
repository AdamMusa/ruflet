# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

# A subclass copied its parent's connection when it was defined, so a model
# defined before ApplicationRecord.establish_connection (models first, then
# the connection) had none and raised ConnectionNotEstablished.
class ConnectionInheritanceTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @application = Class.new(RufletRecord::Base) { self.abstract_class = true }
    @model = Class.new(@application) { self.table_name = "items" }
  end

  def teardown
    @application.connection.close if @application.instance_variable_get(:@connection)
    FileUtils.rm_rf(@dir)
  end

  def test_a_model_uses_the_connection_its_parent_establishes_later
    connection = @application.establish_connection(database: File.join(@dir, "app.sqlite3"))
    RufletRecord::Schema.new(connection).create_table(:items) { |table| table.string :name }

    assert_same connection, @model.connection
    @model.create!(name: "first")
    assert_equal ["first"], @model.pluck(:name)
  end

  def test_a_model_can_still_have_its_own_connection
    @application.establish_connection(database: File.join(@dir, "app.sqlite3"))
    own = @model.establish_connection(database: File.join(@dir, "own.sqlite3"))

    assert_same own, @model.connection
    refute_same own, @application.connection
  ensure
    own&.close
  end
end
