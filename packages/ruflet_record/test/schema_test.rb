# frozen_string_literal: true

require_relative "test_helper"

class SchemaTest < RufletRecordTestCase
  def test_references_can_create_enforced_cascading_foreign_keys
    RufletRecord::Schema.define do
      create_table :labels, if_not_exists: true do |table|
        table.string :name, null: false
      end

      create_table :label_assignments, if_not_exists: true do |table|
        table.references :label, null: false, foreign_key: { on_delete: :cascade }
        table.string :value
      end
    end

    connection = RufletRecord.connection
    label_id = connection.insert('INSERT INTO "labels" ("name") VALUES (?)', ["work"])
    connection.insert(
      'INSERT INTO "label_assignments" ("label_id", "value") VALUES (?, ?)',
      [label_id, "todo"]
    )

    assert_raises(RufletRecord::StatementInvalid) do
      connection.insert(
        'INSERT INTO "label_assignments" ("label_id", "value") VALUES (?, ?)',
        [999_999, "invalid"]
      )
    end

    connection.delete('DELETE FROM "labels" WHERE "id" = ?', [label_id])
    assert_equal 0, connection.select_value('SELECT COUNT(*) FROM "label_assignments"').to_i
  end

  def test_references_support_custom_table_column_and_actions
    RufletRecord::Schema.define do
      create_table :owners, if_not_exists: true do |table|
        table.string :name
      end

      create_table :owned_records, if_not_exists: true do |table|
        table.references :creator,
          foreign_key: {
            to_table: :owners,
            primary_key: :id,
            on_update: :cascade,
            on_delete: :set_null
          }
      end
    end

    sql = RufletRecord.connection.select_value(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
      ["owned_records"]
    )
    assert_includes sql, 'REFERENCES "owners" ("id")'
    assert_includes sql, "ON UPDATE CASCADE"
    assert_includes sql, "ON DELETE SET NULL"
  end

  def test_references_reject_invalid_foreign_key_actions
    assert_raises(ArgumentError) do
      RufletRecord::Schema.define do
        create_table :unsafe_references do |table|
          table.references :user, foreign_key: { on_delete: "CASCADE; DROP TABLE users" }
        end
      end
    end
  end
end
