# frozen_string_literal: true

require_relative "test_helper"
require "sqlite3"

# How a transaction block ends decides what is committed. A non-local exit
# (return, break, throw) skips both the code after `yield` and `rescue`, so it
# must still finish the transaction (issue #93).
class TransactionExitTest < RufletRecordTestCase
  def test_return_out_of_the_block_commits_and_ends_the_transaction
    user = User.create!(name: "Ada")
    assert_equal :renamed, rename(user, "Grace")
    User.create!(name: "Linus")

    assert_transaction_closed
    assert_equal %w[Grace Linus], committed_names
  end

  def test_break_out_of_the_block_commits_and_ends_the_transaction
    [1].each do
      User.transaction do
        User.create!(name: "Ada")
        break
      end
    end

    assert_transaction_closed
    assert_equal ["Ada"], committed_names
  end

  def test_throw_out_of_the_block_commits_and_ends_the_transaction
    caught = catch(:done) do
      User.transaction do
        User.create!(name: "Ada")
        throw :done, :thrown
      end
    end

    assert_equal :thrown, caught
    assert_transaction_closed
    assert_equal ["Ada"], committed_names
  end

  def test_next_and_normal_completion_return_the_block_value
    assert_equal :done, User.transaction { User.create!(name: "Ada"); next :done }
    assert_equal :last, User.transaction { User.create!(name: "Grace"); :last }

    assert_transaction_closed
    assert_equal %w[Ada Grace], committed_names
  end

  def test_return_out_of_a_nested_block_releases_only_its_savepoint
    User.transaction do
      User.create!(name: "Ada")
      assert_equal :inner, nested_return
      assert_equal 1, depth
      begin
        User.transaction do
          User.create!(name: "Bob")
          raise "stop inner"
        end
      rescue RuntimeError
        nil
      end
    end

    assert_transaction_closed
    assert_equal %w[Ada Grace], committed_names
  end

  def test_return_through_nested_blocks_commits_both_levels
    returned_from_both
    assert_transaction_closed
    assert_equal %w[Ada Grace], committed_names
  end

  def test_raise_still_rolls_back_after_an_earlier_return
    rename(User.create!(name: "Ada"), "Grace")
    assert_raises(RuntimeError) do
      User.transaction do
        User.create!(name: "Bob")
        raise "stop"
      end
    end

    assert_transaction_closed
    assert_equal ["Grace"], committed_names
  end

  def test_an_error_raised_in_the_block_propagates_unchanged
    raised = nil
    error = assert_raises(RufletRecord::RecordInvalid) do
      User.transaction do
        User.create!(name: "Ada")
        User.create!(name: nil)
      rescue RufletRecord::RecordInvalid => e
        raised = e
        raise
      end
    end

    assert_same raised, error
    assert_transaction_closed
    assert_empty committed_names
  end

  def test_a_killed_thread_rolls_back
    started = Queue.new
    thread = Thread.new do
      User.transaction do
        User.create!(name: "Ada")
        started << true
        sleep
      end
    end
    started.pop
    thread.kill
    thread.join

    assert_transaction_closed
    assert_empty committed_names
  end

  # Only a block cut short by the kill rolls back; one that runs to the end,
  # here in the dying thread's ensure, commits as it always did.
  def test_a_block_that_completes_while_its_thread_is_being_killed_commits
    started = Queue.new
    thread = Thread.new do
      started << true
      sleep
    ensure
      User.transaction { User.create!(name: "Ada") }
    end
    started.pop
    thread.kill
    thread.join

    assert_transaction_closed
    assert_equal ["Ada"], committed_names
  end

  def test_a_failed_begin_reports_its_own_error
    reconnect(timeout: 50)
    other = SQLite3::Database.new(@database_path)
    other.execute("BEGIN IMMEDIATE")

    error = assert_raises(RufletRecord::StatementInvalid) do
      User.transaction { User.create!(name: "Ada") }
    end
    assert_match(/locked/, error.message)
    assert_equal 0, depth
  ensure
    other&.execute("ROLLBACK")
    other&.close
  end

  def test_a_failed_savepoint_leaves_the_outer_transaction_open
    adapter = RufletRecord.connection
    User.transaction do
      User.create!(name: "Ada")
      fail_next_savepoint(adapter)
      assert_raises(RufletRecord::StatementInvalid) { User.transaction { User.create!(name: "Bob") } }
      assert_equal 1, depth
      User.create!(name: "Grace")
    end

    assert_transaction_closed
    assert_equal %w[Ada Grace], committed_names
  end

  def test_a_failed_commit_rolls_back_and_raises
    adapter = RufletRecord.connection
    error = assert_raises(RufletRecord::StatementInvalid) do
      User.transaction do
        User.create!(name: "Ada")
        fail_next_commit(adapter)
      end
    end
    assert_equal "commit failed", error.message

    assert_transaction_closed
    assert_empty committed_names
  end

  private

  def rename(user, name)
    User.transaction do
      user.update!(name: name)
      return :renamed if user.name == name

      :unchanged
    end
  end

  def nested_return
    User.transaction do
      User.create!(name: "Grace")
      return :inner
    end
  end

  def returned_from_both
    User.transaction do
      User.create!(name: "Ada")
      User.transaction do
        User.create!(name: "Grace")
        return
      end
    end
  end

  def depth
    RufletRecord.connection.instance_variable_get(:@transaction_depth)
  end

  # Closed means: depth 0, and another connection can take the write lock.
  def assert_transaction_closed
    assert_equal 0, depth
    other = SQLite3::Database.new(@database_path)
    other.busy_timeout = 100
    other.execute("BEGIN IMMEDIATE")
    other.execute("ROLLBACK")
  ensure
    other&.close
  end

  # What another connection can read, i.e. what is committed.
  def committed_names
    other = SQLite3::Database.new(@database_path)
    other.busy_timeout = 100
    other.execute("SELECT name FROM users ORDER BY id").flatten
  ensure
    other&.close
  end

  def reconnect(**options)
    RufletRecord.connection.close
    RufletRecord.establish_connection(database: @database_path, **options)
  end

  def fail_next_savepoint(adapter)
    fail_next_statement(adapter, "SAVEPOINT ", "savepoint failed")
  end

  def fail_next_commit(adapter)
    fail_next_statement(adapter, "COMMIT", "commit failed")
  end

  def fail_next_statement(adapter, prefix, message)
    adapter.define_singleton_method(:execute) do |sql, binds = []|
      if sql.start_with?(prefix)
        singleton_class.send(:remove_method, :execute)
        raise RufletRecord::StatementInvalid, message
      end
      super(sql, binds)
    end
  end
end
