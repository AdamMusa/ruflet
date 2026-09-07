# frozen_string_literal: true

require_relative "test_helper"

class AssociationsAndTransactionsTest < RufletRecordTestCase
  def test_belongs_to_has_many_and_has_one
    user = User.create!(name: "Ada")
    post = Post.create!(user_id: user.id, title: "Notes")
    profile = Profile.create!(user_id: user.id, bio: "Mathematician")

    assert_equal user, post.user
    assert_equal [post], user.posts.to_a
    assert_equal profile, user.profile
  end

  def test_transaction_commits
    User.transaction { User.create!(name: "Ada") }
    assert_equal 1, User.count
  end

  def test_transaction_rolls_back
    assert_raises(RuntimeError) do
      User.transaction do
        User.create!(name: "Ada")
        raise "stop"
      end
    end
    assert_equal 0, User.count
  end

  def test_nested_transactions_use_savepoints
    User.transaction do
      User.create!(name: "Ada")
      begin
        User.transaction do
          User.create!(name: "Grace")
          raise "stop inner"
        end
      rescue RuntimeError
        nil
      end
    end

    assert_equal ["Ada"], User.pluck(:name)
  end
end
