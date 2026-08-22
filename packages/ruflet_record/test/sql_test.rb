# frozen_string_literal: true

require_relative "test_helper"

class SQLTest < RufletRecordTestCase
  def test_hash_conditions_use_binds_and_quote_identifiers
    relation = User.where(name: "Ada", age: 20..30, email: nil)

    assert_includes relation.to_sql, %("users"."name" = ?)
    assert_includes relation.to_sql, %("users"."age" BETWEEN ? AND ?)
    assert_includes relation.to_sql, %("users"."email" IS NULL)
    assert_equal ["Ada", 20, 30], relation.bound_attributes
  end

  def test_array_and_empty_array_conditions
    assert_equal [1, 2], User.where(id: [1, 2]).bound_attributes
    assert_includes User.where(id: []).to_sql, "1 = 0"
  end

  def test_string_conditions_require_matching_binds
    assert_equal [18], User.where("age > ?", 18).bound_attributes
    assert_raises(ArgumentError) { User.where("age > ?") }
  end

  def test_order_rejects_untrusted_expressions
    assert_includes User.order(age: :desc).to_sql, %("users"."age" DESC)
    assert_raises(ArgumentError) { User.order("age; DROP TABLE users") }
  end

  def test_relation_compiles_limit_and_offset_as_binds
    relation = User.where(active: true).order(:name).limit(10).offset(5)

    assert_includes relation.to_sql, "ORDER BY"
    assert_includes relation.to_sql, "LIMIT ? OFFSET ?"
    assert_equal [true, 10, 5], relation.bound_attributes
  end

  def test_where_not
    relation = User.where.not(active: false)

    assert_includes relation.to_sql, "NOT"
    assert_equal [false], relation.bound_attributes
  end
end
