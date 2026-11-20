# frozen_string_literal: true

require_relative "test_helper"

# where(column: range) with an open end (18.., ..17, ...18, nil..nil) must
# leave that side unbounded, as Active Record does, instead of binding NULL.
class OpenRangeTest < RufletRecordTestCase
  def setup
    super
    [["Kid", 9], ["Teen", 17], ["Eighteen", 18], ["Adult", 40], ["Unknown", nil]].each do |name, age|
      User.create!(name: name, email: "#{name.downcase}@example.com", age: age)
    end
  end

  def test_endless_range_matches_from_its_begin
    assert_equal %w[Eighteen Adult], names(User.where(age: 18..))
    assert_equal %w[Eighteen Adult], names(User.where(age: 18...))
  end

  def test_beginless_range_matches_up_to_its_end
    assert_equal %w[Kid Teen], names(User.where(age: ..17))
    assert_equal %w[Kid Teen Eighteen], names(User.where(age: ..18))
    assert_equal %w[Kid Teen], names(User.where(age: ...18))
  end

  def test_range_open_at_both_ends_matches_every_row
    assert_equal %w[Kid Teen Eighteen Adult Unknown], names(User.where(age: nil..nil))
    assert_equal %w[Kid Teen Eighteen Adult Unknown], names(User.where(age: nil...nil))
  end

  def test_open_ranges_compile_to_a_single_comparison
    assert_sql_and_binds User.where(age: 18..), %("users"."age" >= ?), [18]
    assert_sql_and_binds User.where(age: 18...), %("users"."age" >= ?), [18]
    assert_sql_and_binds User.where(age: ..17), %("users"."age" <= ?), [17]
    assert_sql_and_binds User.where(age: ...18), %("users"."age" < ?), [18]
    assert_sql_and_binds User.where(age: nil..nil), "1 = 1", []
  end

  def test_bounded_ranges_compile_as_before
    assert_equal %(SELECT "users".* FROM "users" WHERE ("users"."age" BETWEEN ? AND ?)),
                 User.where(age: 20..30).to_sql
    assert_equal [20, 30], User.where(age: 20..30).bound_attributes
    assert_equal %(SELECT "users".* FROM "users" WHERE (("users"."age" >= ? AND "users"."age" < ?))),
                 User.where(age: 20...30).to_sql
    assert_equal [20, 30], User.where(age: 20...30).bound_attributes
    assert_equal %w[Teen Eighteen], names(User.where(age: 17..18))
    assert_equal %w[Teen], names(User.where(age: 17...18))
  end

  def test_open_range_keeps_bind_order_with_other_conditions
    relation = User.where(name: "Adult", age: 18.., email: "adult@example.com")

    assert_includes relation.to_sql, %("users"."name" = ? AND "users"."age" >= ? AND "users"."email" = ?)
    assert_equal ["Adult", 18, "adult@example.com"], relation.bound_attributes
    assert_equal %w[Adult], names(relation)
  end

  def test_where_not_with_open_ranges_is_unchanged
    assert_equal %w[Kid Teen], names(User.where.not(age: 18..))
    assert_equal %w[Eighteen Adult], names(User.where.not(age: ..17))
    assert_equal %w[Eighteen Adult], names(User.where.not(age: ...18))
    assert_equal [], names(User.where.not(age: nil..nil))
  end

  def test_open_ranges_on_time_columns
    User.where(name: %w[Kid Teen]).update_all(created_at: Time.utc(2026, 1, 1, 12, 0, 0))
    User.where(name: %w[Eighteen Adult Unknown]).update_all(created_at: Time.utc(2026, 6, 1, 12, 0, 0))
    since = Time.utc(2026, 3, 1)

    assert_equal %w[Eighteen Adult Unknown], names(User.where(created_at: since..))
    assert_equal %w[Kid Teen], names(User.where(created_at: ..since))
    assert_equal %w[Kid Teen], names(User.where(created_at: ...Time.utc(2026, 6, 1, 12, 0, 0)))
  end

  def test_open_ranges_through_finders_aggregates_and_writes
    assert_equal 2, User.where(age: 18..).count
    assert User.exists?(age: 40..)
    refute User.exists?(age: 41..)
    assert_equal "Kid", User.order(:id).find_by(age: ..9).name

    assert_equal 2, User.where(age: ..17).update_all(active: false)
    assert_equal %w[Kid Teen], names(User.where(active: false))

    assert_equal 2, User.where(age: 18..).delete_all
    assert_equal %w[Kid Teen Unknown], names(User.all)
  end

  def test_create_through_an_open_range_scope_does_not_take_the_bound
    user = User.where(age: 18..).create!(name: "Scoped", email: "scoped@example.com")

    assert_equal 0, user.reload.age
  end

  private

  def names(relation)
    relation.order(:id).pluck(:name)
  end

  def assert_sql_and_binds(relation, condition, binds)
    assert_equal %(SELECT "users".* FROM "users" WHERE (#{condition})), relation.to_sql
    assert_equal binds, relation.bound_attributes
  end
end
