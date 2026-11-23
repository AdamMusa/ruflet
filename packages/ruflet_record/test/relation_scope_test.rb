# frozen_string_literal: true

require_relative "test_helper"

# A relation's limit, offset, distinct and order apply to every method that
# runs it, and model scopes chain on relations. The expected values are what
# Active Record 8.1 returns on SQLite for the same calls.
class RelationScopeTest < RufletRecordTestCase
  def setup
    super
    # Ten users, ages 0..9 in id order. Odd ages have no email.
    @users = (0...10).map do |age|
      User.create!(name: "u#{age}", email: (age.even? ? "u#{age}@example.com" : nil), age: age, active: age < 5)
    end
    [@users[0], @users[0], @users[1], @users[2]].each_with_index do |user, index|
      Post.create!(user_id: user.id, title: "p#{index}")
    end
  end

  # --- update_all and delete_all ----------------------------------------------

  def test_delete_all_with_a_limit_deletes_only_the_limited_rows
    assert_equal 1, User.order(:id).limit(1).delete_all
    assert_equal 9, User.count
    assert_equal (1..9).to_a, User.order(:id).pluck(:age)

    assert_equal 2, User.order(age: :desc).limit(2).delete_all
    assert_equal (1..7).to_a, User.order(:id).pluck(:age)
  end

  def test_delete_all_with_an_offset_skips_the_offset_rows
    assert_equal 1, User.order(:id).offset(9).delete_all
    assert_equal (0..8).to_a, User.order(:id).pluck(:age)

    assert_equal 2, User.where("age < ?", 5).order(:id).limit(2).offset(1).delete_all
    assert_equal [0, 3, 4, 5, 6, 7, 8], User.order(:id).pluck(:age)
  end

  def test_delete_all_with_limit_zero_deletes_nothing
    assert_equal 0, User.limit(0).delete_all
    assert_equal 10, User.count
  end

  def test_delete_all_with_joins_and_a_limit
    with_posts = User.joins('INNER JOIN "posts" ON "posts"."user_id" = "users"."id"')

    assert_equal 1, with_posts.order("users.id").limit(1).delete_all
    assert_equal 9, User.count
    assert_nil User.find_by(age: 0)
  end

  # Active Record 8.1 raises for delete_all on a distinct relation and leaves
  # distinct out of update_all. Here both change each selected row once.
  def test_writes_on_a_distinct_join_with_a_limit_change_each_selected_row_once
    with_posts = User.joins('INNER JOIN "posts" ON "posts"."user_id" = "users"."id"').distinct.order("users.id")

    assert_equal [0, 1], with_posts.limit(2).pluck(:age)
    assert_equal 2, with_posts.limit(2).update_all(name: "posted")
    assert_equal [0, 1], User.where(name: "posted").order(:id).pluck(:age)
    assert_equal 2, with_posts.limit(2).delete_all
    assert_equal (2..9).to_a, User.order(:id).pluck(:age)
  end

  def test_update_all_with_a_limit_updates_only_the_limited_rows
    assert_equal 2, User.order(:id).limit(2).update_all(name: "first two")
    assert_equal [0, 1], User.where(name: "first two").order(:id).pluck(:age)

    assert_equal 3, User.where(active: true).order(age: :desc).limit(3).update_all(name: "top")
    assert_equal [2, 3, 4], User.where(name: "top").order(:id).pluck(:age)
    assert_equal 10, User.count
  end

  def test_update_all_with_an_offset
    assert_equal 2, User.order(:id).offset(8).update_all(name: "last two")
    assert_equal [8, 9], User.where(name: "last two").order(:id).pluck(:age)
  end

  def test_update_all_and_delete_all_without_a_limit_or_offset_send_the_same_sql
    statements = capture_statements do
      User.where(age: 3).update_all(name: "three")
      User.order(:age).where("age > ?", 8).update_all(name: "nine")
      User.distinct.where(age: 4).delete_all
      User.delete_all
    end

    assert_equal [
      [%(UPDATE "users" SET "name" = ? WHERE ("users"."age" = ?)), ["three", 3]],
      [%(UPDATE "users" SET "name" = ? WHERE (age > ?)), ["nine", 8]],
      [%(DELETE FROM "users" WHERE ("users"."age" = ?)), [4]],
      [%(DELETE FROM "users"), []]
    ], statements
  end

  # --- count --------------------------------------------------------------------

  def test_count_with_a_limit_or_offset_counts_the_selected_rows
    assert_equal 2, User.limit(2).count
    assert_equal 2, User.offset(8).count
    assert_equal 0, User.offset(20).count
    assert_equal 0, User.limit(0).count
    assert_equal 10, User.limit(20).count
    assert_equal 3, User.where(active: true).order(:id).limit(3).count
    assert_equal 1, User.where(active: true).order(:id).limit(3).offset(4).count
    assert_equal 3, User.select(:age).limit(3).count
    assert_equal 2, User.limit(2).count(RufletRecord.sql("*"))
  end

  def test_count_of_a_column_with_a_limit_counts_its_non_null_values
    assert_equal 2, User.order(:id).limit(4).count(:email)
    assert_equal 4, User.order(:id).limit(4).count(:age)
  end

  def test_count_of_a_distinct_relation
    assert_equal 2, User.select(:active).distinct.count
    assert_equal 2, User.distinct.count(:active)
    # As in Active Record, NULL is not one of the distinct values counted.
    assert_equal 5, User.select(:email).distinct.count
    assert_equal 6, User.select(:email).distinct.to_a.size
    assert_equal 10, User.distinct.count
    assert_equal 10, User.select(:active, :age).distinct.count
    assert_equal 1, User.select(:active).distinct.limit(1).count
  end

  def test_count_of_a_distinct_join_counts_each_row_once
    with_posts = User.joins('INNER JOIN "posts" ON "posts"."user_id" = "users"."id"')

    assert_equal 4, with_posts.count
    assert_equal 3, with_posts.distinct.count
    assert_equal 3, with_posts.distinct.count(:id)
  end

  def test_count_and_aggregates_without_a_limit_offset_or_distinct_send_the_same_sql
    statements = capture_statements do
      User.count
      User.where(active: true).count(:email)
      User.select(:email).order(:name).count
      User.order(:age).limit(3).sum(:age)
      User.offset(8).maximum(:age)
    end

    assert_equal [
      [%(SELECT COUNT(*) AS value FROM "users"), []],
      [%(SELECT COUNT("users"."email") AS value FROM "users" WHERE ("users"."active" = ?)), [true]],
      [%(SELECT COUNT(*) AS value FROM "users"), []],
      [%(SELECT SUM("users"."age") AS value FROM "users" LIMIT ?), [3]],
      [%(SELECT MAX("users"."age") AS value FROM "users" LIMIT -1 OFFSET ?), [8]]
    ], statements
  end

  # --- last ---------------------------------------------------------------------

  def test_last_follows_the_relation_order
    assert_equal 0, User.order(age: :desc).last.age
    assert_equal [1, 0], User.order(age: :desc).last(2).map(&:age)
    assert_equal 9, User.order(:age).last.age
    assert_equal 0, User.order("age DESC").last.age
    assert_equal [2, 1, 0], User.order("active ASC, age DESC").last(3).map(&:age)
    assert_equal 8, User.order(:email, age: :desc).last.age
  end

  def test_last_with_an_sql_order
    assert_equal 0, User.order(RufletRecord.sql("age * -1")).last.age
    assert_equal [1, 0], User.order(RufletRecord.sql("age * -1")).last(2).map(&:age)
    assert_equal 9, User.order(RufletRecord.sql("LOWER(email) DESC, age")).last.age
    assert_equal 10, User.order(RufletRecord.sql("age * -1")).last(20).size
    assert_equal [], User.order(RufletRecord.sql("age * -1")).last(0)
  end

  def test_last_with_a_limit_or_offset_is_the_last_selected_row
    assert_equal 2, User.order(:id).limit(3).last.age
    assert_equal 2, User.limit(3).last.age
    assert_equal 9, User.offset(2).last.age
    assert_equal [8, 7], User.order(age: :desc).limit(3).last(2).map(&:age)
    assert_nil User.limit(0).last
  end

  # order(params[:sort]) with no sort given. Active Record ignores a blank
  # order entry, and so do last, and count and the writes with a limit.
  def test_blank_order_entries_are_ignored
    sort = nil

    assert_equal 9, User.order(sort).last.age
    assert_equal 9, User.reorder(nil).last.age
    assert_equal 9, User.order("").last.age
    assert_equal 9, User.order({}).last.age
    assert_equal 9, User.order(RufletRecord.sql("")).last.age
    assert_equal [8, 9], User.order(sort).last(2).map(&:age)
    assert_equal 0, User.order(age: :desc).order(sort).last.age
    assert_equal 0, User.order(RufletRecord.sql("age * -1"), sort).last.age
    assert_equal 2, User.order(sort).limit(3).last.age
    assert_equal 2, User.order(sort).limit(2).count
    assert_equal 1, User.order(sort).order(:id).limit(2).count(:email)
    assert_equal 2, User.order(sort).limit(2).update_all(name: "two")
    assert_equal 2, User.where(name: "two").count
    assert_equal 2, User.order(sort).order(:id).limit(2).update_all(name: "first two")
    assert_equal [0, 1], User.where(name: "first two").order(:id).pluck(:age)
    assert_equal 1, User.order(sort).limit(1).delete_all
    assert_equal 9, User.count
  end

  def test_last_without_an_order_or_limit_sends_the_same_sql
    statements = capture_statements do
      User.last
      User.where(active: true).last(2)
      User.order(nil).last
    end

    assert_equal [
      [%(SELECT "users".* FROM "users" ORDER BY "users"."id" DESC LIMIT ?), [1]],
      [%(SELECT "users".* FROM "users" WHERE ("users"."active" = ?) ORDER BY "users"."id" DESC LIMIT ?), [true, 2]],
      [%(SELECT "users".* FROM "users" ORDER BY "users"."id" DESC LIMIT ?), [1]]
    ], statements
  end

  # --- find_each ----------------------------------------------------------------

  def test_find_each_stops_at_the_relation_limit
    assert_equal [0, 1, 2], visited(User.limit(3), batch_size: 2)
    assert_equal [0, 1, 2], visited(User.limit(3), batch_size: 1000)
    assert_equal [0, 1, 2, 3], visited(User.limit(4), batch_size: 2)
    assert_equal [], visited(User.limit(0), batch_size: 2)
    assert_equal [5, 6], visited(User.where("age >= ?", 5).limit(2), batch_size: 10)
  end

  def test_find_each_without_a_limit_sends_the_same_sql
    statements = capture_statements { visited(User.where("age > ?", 6), batch_size: 2) }

    assert_equal [
      [%(SELECT "users".* FROM "users" WHERE (age > ?) ORDER BY "users"."id" ASC LIMIT ?), [6, 2]],
      [%(SELECT "users".* FROM "users" WHERE (age > ?) AND ("users"."id" > ?) ORDER BY "users"."id" ASC LIMIT ?), [6, @users[8].id, 2]],
      [%(SELECT "users".* FROM "users" WHERE (age > ?) AND ("users"."id" > ?) ORDER BY "users"."id" ASC LIMIT ?), [6, @users[9].id, 2]]
    ], statements
  end

  # --- scopes -------------------------------------------------------------------

  def test_scopes_chain_on_relations
    User.class_eval do
      scope :older_than, ->(age) { where("age > ?", age) }
      scope :with_email, -> { where("email IS NOT NULL") }
    end

    assert_equal [2, 4], User.active.with_email.where("age > ?", 0).order(:id).pluck(:age)
    assert_equal [6, 8], User.with_email.older_than(5).order(:id).pluck(:age)
    assert_equal [3, 4], User.where(active: true).older_than(2).order(:id).pluck(:age)
    assert_equal 2, User.active.older_than(2).count
    assert User.where(active: true).respond_to?(:older_than)
  end

  def test_a_scope_with_an_order_and_limit_merges_into_the_relation
    User.class_eval { scope :top_two, -> { order(age: :desc).limit(2) } }

    assert_equal [4, 3], User.where(active: true).top_two.pluck(:age)
    assert_equal [0, 1], User.order(:id).top_two.pluck(:age)
  end

  def test_a_scope_that_reorders_replaces_the_order
    User.class_eval do
      scope :oldest_first, -> { reorder(age: :desc) }
      scope :oldest_active, -> { where(active: true).oldest_first }
    end

    assert_equal 9, User.order(:id).oldest_first.first.age
    assert_equal 4, User.order(:id).oldest_active.first.age
    assert_equal 0, User.where(active: true).order(:id).oldest_first.last.age
    assert_equal [9, 8, 7], User.oldest_first.order(:id).limit(3).pluck(:age)
    # merge keeps adding the other relation's order, as it did before.
    assert_equal [0, 1], User.order(:id).merge(User.reorder(age: :desc)).limit(2).pluck(:age)
  end

  def test_a_scope_returning_nil_keeps_the_relation
    User.class_eval { scope :nothing, -> {} }

    assert_equal 5, User.where(active: true).nothing.count
  end

  def test_scopes_chain_on_association_readers
    Post.class_eval { scope :titled, ->(title) { where(title: title) } }

    assert_equal ["p1"], @users[0].posts.titled("p1").pluck(:title)
    assert_equal [], @users[1].posts.titled("p1").pluck(:title)
  end

  def test_a_subclass_chains_the_scopes_it_inherits
    admin = Class.new(User) { self.table_name = "users" }

    assert_equal [0, 1], admin.where("age < ?", 2).active.order(:id).pluck(:age)
  end

  def test_a_scope_over_another_model_cannot_chain
    Post.class_eval { scope :authors, -> { User.all } }

    assert_raises(ArgumentError) { Post.where(title: "p0").authors }
  end

  # mruby raises NoMethodError for a private method called with a receiver
  # before method_missing runs, so such a scope cannot chain on a device.
  # It raises under CRuby too, and still works on the model.
  def test_a_scope_named_after_a_private_kernel_method_does_not_chain
    User.class_eval { scope :open, -> { where(active: true) } }

    assert_equal 5, User.open.count
    assert_equal 3, User.open.where("age > ?", 1).count
    refute User.where("age > ?", 1).respond_to?(:open)
    assert_raises(NoMethodError) { User.where("age > ?", 1).open }
  end

  def test_class_methods_that_are_not_scopes_are_not_delegated
    User.define_singleton_method(:total_age) { sum(:age) }

    relation = User.where(active: true)
    refute relation.respond_to?(:total_age)
    assert_raises(NoMethodError) { relation.total_age }
    assert_raises(NoMethodError) { relation.not_a_scope }
  end

  private

  def capture_statements
    statements = []
    connection = RufletRecord.connection
    original = connection.method(:execute)
    connection.define_singleton_method(:execute) do |sql, binds = []|
      statements << [sql, binds] unless sql.start_with?("PRAGMA")
      original.call(sql, binds)
    end
    yield
    statements
  ensure
    connection.singleton_class.send(:remove_method, :execute)
  end

  def visited(relation, batch_size:)
    ages = []
    relation.find_each(batch_size: batch_size) { |user| ages << user.age }
    ages
  end
end
