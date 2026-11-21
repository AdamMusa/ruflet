# frozen_string_literal: true

require_relative "test_helper"
require "sqlite3"
require "timeout"

# Every thread shares the one connection (ruflet_server runs a thread per
# client). A thread must never run its statements inside another thread's
# transaction, or read the row id or change count of another thread's
# statement (issue #124).
class ConnectionThreadsTest < RufletRecordTestCase
  def test_another_threads_writes_wait_for_a_transaction_and_survive_its_rollback
    a_open = Queue.new
    b_done = Queue.new
    a = Thread.new do
      User.transaction do
        User.create!(name: "A, rolled back")
        a_open << true
        # Gives B time to write. B now waits for this block instead.
        wait_for(b_done, 0.5)
        raise "A fails"
      end
    rescue RuntimeError
      nil
    end
    b = Thread.new do
      a_open.pop
      User.transaction { User.create!(name: "B, own transaction") }
      User.create!(name: "B, plain create")
      b_done << true
    end
    [a, b].each(&:join)

    assert_equal ["B, own transaction", "B, plain create"], committed_names
    assert_equal 0, depth
  end

  def test_another_thread_does_not_see_uncommitted_rows
    a_open = Queue.new
    a_finish = Queue.new
    a = Thread.new do
      User.transaction do
        User.create!(name: "Ada")
        a_open << true
        wait_for(a_finish, 0.3)
        raise "A fails"
      end
    rescue RuntimeError
      nil
    end
    a_open.pop
    count = User.count
    a_finish << true
    a.join

    assert_equal 0, count
  end

  def test_each_thread_reads_the_id_of_its_own_insert
    adapter = RufletRecord.connection
    other_inserted = Queue.new
    pause_after_first(adapter, :last_insert_row_id) { wait_for(other_inserted, 0.3) }

    a = Thread.new { User.create!(name: "Ada") }
    sleep 0.05
    b = Thread.new do
      user = User.create!(name: "Bob")
      other_inserted << true
      user
    end
    ada = a.value
    bob = b.value

    assert_equal "Ada", User.find(ada.id).name
    assert_equal "Bob", User.find(bob.id).name
    refute_equal ada.id, bob.id
  end

  def test_each_thread_reads_the_change_count_of_its_own_update
    User.create!(name: "Ada")
    User.create!(name: "Ada")
    User.create!(name: "Bob")
    adapter = RufletRecord.connection
    other_updated = Queue.new
    pause_after_first(adapter, :changes) { wait_for(other_updated, 0.3) }

    a = Thread.new { User.where(name: "Ada").update_all(age: 1) }
    sleep 0.05
    b = Thread.new do
      count = User.where(name: "Bob").update_all(age: 2)
      other_updated << true
      count
    end

    assert_equal 2, a.value
    assert_equal 1, b.value
  end

  def test_a_thread_waits_at_most_the_busy_timeout
    reconnect(timeout: 100)
    a_open = Queue.new
    b_done = Queue.new
    a = Thread.new do
      User.transaction do
        User.create!(name: "Ada")
        a_open << true
        wait_for(b_done, 2)
      end
    end
    a_open.pop
    started = monotonic_now
    error = assert_raises(RufletRecord::RecordNotSaved) { User.create!(name: "Bob") }
    waited = monotonic_now - started
    b_done << true
    a.join

    assert_match(/database is locked/, error.message)
    assert_operator waited, :>=, 0.09
    assert_operator waited, :<, 1.5
    assert_equal ["Ada"], committed_names
  end

  def test_killing_the_transaction_thread_lets_a_waiting_thread_write
    a_open = Queue.new
    a = Thread.new do
      User.transaction do
        User.create!(name: "Ada")
        a_open << true
        sleep
      end
    end
    a_open.pop
    waiting = Thread.new { User.create!(name: "Bob") }
    sleep 0.05
    assert_equal "sleep", waiting.status, "Bob waits for Ada's transaction"
    a.kill
    a.join
    waiting.join

    assert_equal ["Bob"], committed_names
    assert_equal 0, depth
  end

  def test_a_killed_waiting_thread_takes_nothing
    a_open = Queue.new
    a = Thread.new do
      User.transaction do
        User.create!(name: "Ada")
        a_open << true
        sleep
      end
    end
    a_open.pop
    waiting = Thread.new { User.create!(name: "Bob") }
    sleep 0.05
    assert_equal "sleep", waiting.status, "Bob waits for Ada's transaction"
    waiting.kill
    waiting.join
    a.kill
    a.join

    User.create!(name: "Grace")
    assert_equal ["Grace"], committed_names
    assert_equal 0, depth
  end

  def test_a_timeout_while_waiting_takes_nothing
    a_open = Queue.new
    b_done = Queue.new
    a = Thread.new do
      User.transaction do
        User.create!(name: "Ada")
        a_open << true
        wait_for(b_done, 2)
      end
    end
    a_open.pop
    assert_raises(Timeout::Error) { Timeout.timeout(0.05) { User.create!(name: "Bob") } }
    b_done << true
    a.join

    User.create!(name: "Grace")
    assert_equal %w[Ada Grace], committed_names
    assert_equal 0, depth
  end

  # The connection belongs to a thread, not a fiber: an Enumerator stepped
  # inside a transaction block runs its statements in that transaction.
  def test_an_enumerator_inside_a_transaction_uses_the_same_connection
    reconnect(timeout: 100)
    names = User.transaction do
      User.create!(name: "Ada")
      Enumerator.new { |yielder| yielder << User.pluck(:name) }.next
    end

    assert_equal ["Ada"], names
    assert_equal ["Ada"], committed_names
  end

  private

  def depth
    RufletRecord.connection.instance_variable_get(:@transaction_depth)
  end

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

  # Waits up to +seconds+ for an item on +queue+; true when one came.
  def wait_for(queue, seconds)
    deadline = monotonic_now + seconds
    sleep 0.005 while queue.empty? && monotonic_now < deadline
    !queue.empty?
  end

  # Runs +pause+ before the first call of the driver's +method+ returns, which
  # leaves room for another thread's statement in between.
  def pause_after_first(adapter, method, &pause)
    driver = adapter.instance_variable_get(:@driver)
    driver.define_singleton_method(method) do
      singleton_class.send(:remove_method, method)
      pause.call
      public_send(method)
    end
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
