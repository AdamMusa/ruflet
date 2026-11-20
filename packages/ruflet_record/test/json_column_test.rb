# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"

# Assigning a Hash or Array to a model failed: sqlite3 reads a Hash bind as
# named parameters ("no such bind parameter") and flattens an Array into
# positional binds, and the device VM stored inspect text. A model now
# stores both as JSON text. A json column is still TEXT and reads back the
# stored text, so every other value behaves exactly as before, and raw SQL
# binds still reach sqlite3 unchanged.
class JsonColumnTest < RufletRecordTestCase
  def setup
    super
    RufletRecord::Schema.define do
      create_table :settings do |table|
        table.string :name
        table.json :value
      end
    end
    Object.const_set(:Setting, Class.new(RufletRecord::Base))
  end

  def teardown
    Object.send(:remove_const, :Setting) if Object.const_defined?(:Setting)
    super
  end

  def test_hashes_and_arrays_are_stored_as_json_text
    theme = Setting.create!(name: "theme", value: { "mode" => "dark", "accents" => ["teal", 3] })
    recent = Setting.create!(name: "recent", value: [1, "two", nil])

    stored = Setting.find(theme.id).value
    assert_equal({ "mode" => "dark", "accents" => ["teal", 3] }, JSON.parse(stored))
    assert_equal "[1,\"two\",null]", Setting.find(recent.id).value
    assert_equal [theme.id], Setting.where("json_extract(value, '$.mode') = ?", "dark").ids
  end

  def test_updates_store_json_text
    setting = Setting.create!(name: "limit", value: { "max" => 1 })

    setting.update!(value: { "max" => 2 })
    assert_equal({ "max" => 2 }, JSON.parse(setting.reload.value))

    setting.update_columns(value: ["a"])
    assert_equal "[\"a\"]", setting.reload.value

    setting.update!(value: nil)
    assert_nil setting.reload.value
    assert_equal [setting.id], Setting.where(value: nil).ids
  end

  # These values worked before the fix; they must read back unchanged.
  def test_strings_booleans_and_numbers_read_back_as_before
    {
      JSON.generate("theme" => "dark") => "{\"theme\":\"dark\"}",
      "007" => "007",
      "true" => "true",
      "\"quoted\"" => "\"quoted\"",
      "12345678901234567890" => "12345678901234567890",
      true => "1",
      false => "0",
      1.0 => "1.0",
      2.5 => "2.5",
      5 => "5"
    }.each do |assigned, stored|
      record = Setting.create!(name: assigned.inspect, value: assigned)

      assert_equal assigned, record.value, "in memory: #{assigned.inspect}"
      assert_equal stored, Setting.find(record.id).value, "reloaded: #{assigned.inspect}"
    end
  end

  def test_an_app_encoded_string_is_found_and_parsed_as_before
    prefs = Setting.create!(name: "prefs", value: JSON.generate("theme" => "dark"))

    assert_equal({ "theme" => "dark" }, JSON.parse(Setting.find_by(name: "prefs").value))
    assert_equal [prefs.id], Setting.where(value: "{\"theme\":\"dark\"}").ids
  end

  def test_the_column_is_text
    column = Setting.columns_hash["value"]

    assert_equal "TEXT", column.sql_type
    assert_equal :string, column.type
  end

  def test_hash_conditions_and_update_all_bind_json_text
    theme = Setting.create!(name: "theme", value: { "mode" => "dark" })
    Setting.create!(name: "recent", value: [1, 2])

    assert_equal [theme.id], Setting.where(value: { "mode" => "dark" }).ids
    assert_equal [theme.id], Setting.where("value = ?", JSON.generate("mode" => "dark")).ids
    assert_equal ["recent"], Setting.where.not(value: { "mode" => "dark" }).pluck(:name)
    assert_equal ["theme", "recent"], Setting.where(value: [{ "mode" => "dark" }, [1, 2]]).order(:id).pluck(:name)
    assert_equal theme, Setting.find_or_create_by(value: { "mode" => "dark" })

    # An Array condition is still an IN list; its Hash or Array items are JSON.
    assert_equal 0, Setting.where(value: [1, 2]).count
    assert_equal 1, Setting.where(value: [[1, 2]]).count
    Setting.where(name: "recent").update_all(value: { "max" => 3 })
    assert_equal ["{\"max\":3}"], Setting.where(name: "recent").pluck(:value)
    assert_equal 1, Setting.where(value: { "max" => 3 }).update_all(name: "capped")
    assert_equal 1, Setting.where(value: { "max" => 3 }).delete_all
  end

  # bound_attributes shows the values as given, as before.
  def test_bound_attributes_keep_the_given_values
    assert_equal [{ "mode" => "dark" }], Setting.where(value: { "mode" => "dark" }).bound_attributes
  end

  # Raw SQL binds go to sqlite3 as before: a Hash is a set of named
  # parameters and an Array is flattened into positional binds.
  def test_raw_sql_binds_reach_sqlite_unchanged
    connection = RufletRecord.connection
    connection.execute("INSERT INTO settings (name, value) VALUES (:name, :value)", [{ name: "raw", value: "v" }])
    connection.execute("INSERT INTO settings (name, value) VALUES (?, ?)", [["list", "w"]])

    assert_equal [{ "name" => "raw", "value" => "v" }],
      connection.select_all("SELECT name, value FROM settings WHERE name = :name", [{ name: "raw" }])
    assert_equal ["raw", "list"],
      connection.select_all("SELECT name FROM settings WHERE name = ? OR value = ? ORDER BY id", [["raw", "w"]]).map { |row| row["name"] }
    assert_equal ["raw"], Setting.where("name IN (?)", ["raw"]).pluck(:name)
    assert_raises(RufletRecord::StatementInvalid) { Setting.where("name IN (?)", ["raw", "list"]).to_a }
  end

  def test_without_a_json_library_the_value_is_bound_unchanged
    sql = RufletRecord::SQL.singleton_class
    sql.send(:alias_method, :json_library_before_test, :json_library)
    sql.send(:remove_method, :json_library)
    sql.send(:define_method, :json_library) { nil }

    assert_equal [{ "a" => 1 }, [1], "x"], [{ "a" => 1 }, [1], "x"].map { |value| RufletRecord::SQL.column_value(value) }
  ensure
    sql.send(:remove_method, :json_library)
    sql.send(:alias_method, :json_library, :json_library_before_test)
    sql.send(:remove_method, :json_library_before_test)
  end

  # The device VM's framework code cannot require json at load time, so it
  # is required the first time a model binds a Hash or Array.
  def test_json_is_required_when_first_needed
    script = <<~RUBY
      require "ruflet_record"
      before = Object.const_defined?(:JSON)
      RufletRecord.establish_connection(database: ":memory:")
      RufletRecord.connection.execute("CREATE TABLE settings (id INTEGER PRIMARY KEY, value TEXT)")
      Setting = Class.new(RufletRecord::Base)
      record = Setting.create!(value: { "a" => [1] })
      print [before, Setting.find(record.id).value].inspect
    RUBY
    lib = File.expand_path("../lib", __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, "-I", lib, "-e", script)

    assert status.success?, output
    assert_equal [false, "{\"a\":[1]}"].inspect, output
  end
end
