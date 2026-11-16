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
end
