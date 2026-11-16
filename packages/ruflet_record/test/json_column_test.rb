# frozen_string_literal: true

require_relative "test_helper"

# Schema's json columns were plain TEXT: assigning a Hash raised
# "no such bind parameter" (sqlite3 read it as named binds) and an Array was
# rejected, so a json column could only hold strings the app encoded itself.
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

  def test_hashes_and_arrays_round_trip
    theme = Setting.create!(name: "theme", value: { "mode" => "dark", "accents" => ["teal", 3] })
    recent = Setting.create!(name: "recent", value: [1, "two", nil])

    assert_equal({ "mode" => "dark", "accents" => ["teal", 3] }, Setting.find(theme.id).value)
    assert_equal [1, "two", nil], Setting.find(recent.id).value
  end

  def test_updates_and_scalars_are_stored
    setting = Setting.create!(name: "limit", value: { "max" => 1 })

    setting.update!(value: { "max" => 2 })
    assert_equal({ "max" => 2 }, setting.reload.value)

    setting.update!(value: 5)
    assert_equal 5, setting.reload.value

    setting.update!(value: nil)
    assert_nil setting.reload.value
    assert_equal [setting.id], Setting.where(value: nil).ids
  end

  def test_the_column_reports_json
    assert_equal :json, Setting.columns_hash["value"].type
  end
end
