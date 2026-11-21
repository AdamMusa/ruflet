# frozen_string_literal: true

require_relative "test_helper"

# belongs_to defines a writer (post.user = user), but new, create and update
# sent every key straight to write_attribute, which knows only columns, so
# Post.create!(user: user) raised UnknownAttributeError.
class AssociationAttributesTest < RufletRecordTestCase
  def test_new_create_and_update_take_a_belongs_to_record
    ada = User.create!(name: "Ada", email: "ada@example.com")
    grace = User.create!(name: "Grace", email: "grace@example.com")

    post = Post.create!(user: ada, title: "Notes")
    assert_equal ada.id, Post.find(post.id).user_id
    assert_equal ada, post.user

    post.update!(user: grace)
    assert_equal grace.id, post.reload.user_id

    assert_equal grace.id, Post.new(user: grace, title: "Draft").user_id
  end

  def test_unknown_names_still_fail_fast
    assert_raises(RufletRecord::UnknownAttributeError) { Post.new(author: nil) }
  end

  # Only belongs_to writers are used; other writers raised before and still do.
  def test_other_writers_are_not_attributes
    post_class = Class.new(RufletRecord::Base) do
      self.table_name = "posts"
      attr_accessor :draft
    end

    assert_raises(RufletRecord::UnknownAttributeError) { post_class.new(draft: true) }
    ["=", "!", "[]"].each do |name|
      assert_raises(RufletRecord::UnknownAttributeError, name) { Post.new(name => 1) }
    end
  end

  def test_a_belongs_to_declared_on_a_parent_class
    parent = Class.new(RufletRecord::Base) do
      self.abstract_class = true
      belongs_to :user
    end
    entry = Class.new(parent) { self.table_name = "posts" }
    ada = User.create!(name: "Ada")

    assert_equal ada.id, entry.create!(user: ada, title: "Inherited").reload.user_id
  end

  # A column keeps going to write_attribute, as before, even when a
  # belongs_to shares its name: user: 5 writes the user column.
  def test_a_column_named_like_a_belongs_to_is_written_directly
    RufletRecord.connection.execute("CREATE TABLE notes (id INTEGER PRIMARY KEY, user INTEGER)")
    note_class = Class.new(RufletRecord::Base) do
      self.table_name = "notes"
      belongs_to :user, foreign_key: "user"
    end
    ada = User.create!(name: "Ada")

    assert_equal 5, note_class.new(user: 5).read_attribute("user")
    note = note_class.create!(user: ada.id)
    assert_equal ada.id, note_class.find(note.id).read_attribute("user")
    note.update!(user: 7)
    assert_equal 7, note.reload.read_attribute("user")
  end
end
