# frozen_string_literal: true

require_relative "test_helper"

class RelationTest < RufletRecordTestCase
  def setup
    super
    @ada = User.create!(name: "Ada", email: "ada@example.com", age: 36, active: true)
    @grace = User.create!(name: "Grace", email: "grace@example.com", age: 28, active: false)
    @linus = User.create!(name: "Linus", email: "linus@example.com", age: 54, active: true)
  end

  def test_relations_are_chainable_and_immutable
    adults = User.where("age >= ?", 30)
    ordered = adults.order(age: :desc).limit(1)

    assert_equal 2, adults.count
    assert_equal ["Linus"], ordered.pluck(:name)
  end

  def test_query_building_is_lazy_until_data_is_requested
    connection = RufletRecord.connection
    query_count = 0
    original = connection.method(:select_all)
    connection.define_singleton_method(:select_all) do |sql, binds = []|
      query_count += 1
      original.call(sql, binds)
    end

    relation = User.where(active: true).order(:name).limit(2)
    assert_equal 0, query_count
    refute relation.loaded?

    assert_equal ["Ada", "Linus"], relation.pluck(:name)
    assert_equal 1, query_count
  end

  def test_aggregates_and_selection
    assert_equal 3, User.count
    assert_equal 118, User.sum(:age)
    assert_equal 28, User.minimum(:age)
    assert_equal 54, User.maximum(:age)
    assert_equal [@ada.id, @linus.id], User.active.order(:id).ids
    assert User.exists?(email: "ada@example.com")
    refute User.exists?(email: "nobody@example.com")
  end

  def test_update_all_and_delete_all
    assert_equal 2, User.active.update_all(active: false)
    assert_equal 0, User.active.count
    assert_equal 3, User.where(active: false).delete_all
    assert_equal 0, User.count
  end

  def test_find_each_visits_every_record
    names = []
    User.find_each(batch_size: 2) { |user| names << user.name }
    assert_equal %w[Ada Grace Linus], names
  end

  def test_first_last_pick_and_pluck
    assert_equal "Ada", User.order(:id).first.name
    assert_equal "Linus", User.last.name
    assert_equal ["Ada", 36], User.order(:id).pick(:name, :age)
    assert_equal [["Ada", 36], ["Grace", 28]], User.order(:id).limit(2).pluck(:name, :age)
  end
end
