# frozen_string_literal: true

require_relative "test_helper"

# The adapter passed PRAGMA table_info's notnull flag as Column's null
# argument, so null? was true exactly for the NOT NULL columns.
class ColumnNullTest < RufletRecordTestCase
  def test_null_reports_whether_the_column_accepts_null
    refute User.columns_hash["name"].null?, "name is NOT NULL"
    assert User.columns_hash["email"].null?
  end
end
