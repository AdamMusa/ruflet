# frozen_string_literal: true

require_relative "test_helper"

class ModelTest < RufletRecordTestCase
  def test_create_find_update_reload_and_destroy
    user = User.create!(name: "Ada", email: "ada@example.com", age: 36)

    assert user.persisted?
    assert_kind_of Integer, user.id
    assert_equal "Ada", User.find(user.id).name
    assert user.update(name: "Ada Lovelace")
    assert_equal "Ada Lovelace", user.reload.name

    user.destroy
    assert user.destroyed?
    assert_raises(RufletRecord::RecordNotFound) { User.find(user.id) }
  end

  def test_attributes_are_type_cast
    user = User.create!(name: "Grace", age: "42", active: "0")
    loaded = User.find(user.id)

    assert_equal 42, loaded.age
    assert_equal false, loaded.active
  end

  def test_presence_and_uniqueness_validation
    invalid = User.new(name: "")
    refute invalid.save
    assert_includes invalid.errors[:name], "can't be blank"

    User.create!(name: "Ada", email: "ada@example.com")
    duplicate = User.new(name: "Other", email: "ada@example.com")
    refute duplicate.save
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  def test_unknown_attributes_fail_fast
    assert_raises(RufletRecord::UnknownAttributeError) { User.new(unknown: true) }
  end

  def test_timestamps_and_dirty_tracking
    user = User.create!(name: "Ada")
    refute user.changed?
    refute_nil user.created_at
    refute_nil user.updated_at

    user.name = "Grace"
    assert user.changed?
    assert_equal ["Ada", "Grace"], user.changes["name"]
  end
end
