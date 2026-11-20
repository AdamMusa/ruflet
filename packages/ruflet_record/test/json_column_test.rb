# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"

# Assigning a Hash or Array failed: sqlite3 reads a Hash bind as named
# parameters ("no such bind parameter") and rejects an Array, and the device
# VM stored inspect text. Both are now stored as JSON text. A json column is
# still TEXT and reads back the stored text, so every other value behaves
# exactly as before.
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

  def test_without_a_json_library_the_value_is_bound_unchanged
    adapter = Setting.connection
    adapter.define_singleton_method(:json_library) { nil }

    assert_equal [{ "a" => 1 }, [1], "x"], adapter.send(:normalize_binds, [{ "a" => 1 }, [1], "x"])
  ensure
    adapter.singleton_class.send(:remove_method, :json_library)
  end

  # The device VM's framework code cannot require json at load time, so the
  # adapter requires it the first time a Hash or Array is bound.
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
