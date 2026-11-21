# frozen_string_literal: true

require_relative "test_helper"
require "sqlite3"
require "timeout"

# Every thread shares the one connection (ruflet_server runs a thread per
# client). A thread must never run its statements inside another thread's
# transaction, or read the row id or change count of another thread's
# statement (issue #124).
class ConnectionThreadsTest < RufletRecordTestCase
  Interrupted = Class.new(StandardError)

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

  def test_the_lock_waits_at_most_its_timeout
    lock = RufletRecord::Adapters::ThreadLock.new(100)
    held = Queue.new
    release = Queue.new
    holder = Thread.new { lock.synchronize { held << true; release.pop } }
    held.pop
    started = monotonic_now
    error = assert_raises(RufletRecord::StatementInvalid) { lock.synchronize { flunk "took a held lock" } }
    waited = monotonic_now - started
    release << true
    holder.join

    assert_match(/database is locked .*over 100 ms/, error.message)
    assert_operator waited, :>=, 0.09
    assert_operator waited, :<, 3
  end

  # A busy timeout shorter than the default does not shorten the wait for
  # another thread; a longer one lengthens it.
  def test_a_thread_waits_at_most_the_busy_timeout_and_at_least_the_default
    reconnect(timeout: 0)
    a, finish = open_transaction("Ada")
    started = monotonic_now
    error = assert_raises(RufletRecord::RecordNotSaved) { User.create!(name: "Bob") }
    waited = monotonic_now - started
    finish << true
    a.join

    assert_match(/database is locked/, error.message)
    assert_operator waited, :>=, 4.9
    assert_operator waited, :<, 20
    assert_equal [], committed_names

    reconnect(timeout: 7_000)
    assert_equal 7_000, RufletRecord.connection.instance_variable_get(:@lock).instance_variable_get(:@timeout_ms)
  end

  # With no transaction, two threads' statements overlap all the time, and
  # none of them fails, as with no lock.
  def test_plain_writes_on_two_threads_all_succeed_with_a_zero_timeout
    reconnect(timeout: 0)
    writers = %w[a b].map do |who|
      Thread.new { 300.times { |i| User.create!(name: "#{who}#{i}") } }
    end
    writers.each(&:join)

    assert_equal 600, User.count
  end

  def test_killing_the_transaction_thread_lets_a_waiting_thread_write
    reconnect(timeout: 60_000)
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
    assert wait_until { waiting.status == "sleep" }, "Bob waits for Ada's transaction"
    a.kill
    a.join
    refute_nil waiting.join(10), "Bob writes as soon as Ada's transaction ends"

    assert_equal ["Bob"], committed_names
    assert_equal 0, depth
  end

  def test_a_killed_waiting_thread_takes_nothing
    reconnect(timeout: 60_000)
    a, finish = open_transaction("Ada")
    waiting = Thread.new { User.create!(name: "Bob") }
    assert wait_until { waiting.status == "sleep" }, "Bob waits for Ada's transaction"
    waiting.kill
    refute_nil waiting.join(10), "a waiting thread can be killed at once"
    assert_still_holds_the_connection(a, finish)

    User.create!(name: "Grace")
    assert_equal %w[Carol Grace], committed_names
    assert_equal 0, depth
  end

  def test_a_timeout_while_waiting_takes_nothing
    reconnect(timeout: 60_000)
    a, finish = open_transaction("Ada")
    started = monotonic_now
    assert_raises(Timeout::Error) { Timeout.timeout(0.05) { User.create!(name: "Bob") } }
    assert_operator monotonic_now - started, :<, 5, "a waiting thread can be timed out at once"
    assert_still_holds_the_connection(a, finish)

    User.create!(name: "Grace")
    assert_equal %w[Carol Grace], committed_names
    assert_equal 0, depth
  end

  # Thread#raise and Thread#kill that arrive while a thread takes the lock
  # wait until it holds it, so they release it on the way out.
  def test_a_thread_raise_while_taking_the_lock_leaves_it_free
    lock = RufletRecord::Adapters::ThreadLock.new(0)
    thread = interrupt_while_taking(lock) { |target| target.raise(Interrupted) }
    assert_equal :interrupted, thread[:outcome]
    assert thread.alive?
    assert_equal :taken, lock.synchronize { :taken }
    assert lock_free?(lock)
  ensure
    thread&.kill&.join
  end

  def test_a_thread_kill_while_taking_the_lock_leaves_it_free
    lock = RufletRecord::Adapters::ThreadLock.new(0)
    thread = interrupt_while_taking(lock, &:kill)
    refute thread.alive?
    assert lock_free?(lock)
  end

  # A forked child has only the thread that forked, so a lock another
  # thread held at the fork is free there.
  def test_a_lock_whose_owner_is_gone_is_free
    skip "no fork here" unless Process.respond_to?(:fork)
    lock = RufletRecord::Adapters::ThreadLock.new(0)
    held = Queue.new
    holder = Thread.new { lock.synchronize { held << true; sleep } }
    held.pop
    # The child must not inherit an open SQLite connection.
    RufletRecord.connection.close
    pid = fork do
      taken = begin
        lock.synchronize { true }
      rescue RufletRecord::StatementInvalid
        false
      end
      exit!(taken ? 0 : 1)
    end
    _, status = Process.wait2(pid)
    holder.kill
    holder.join

    assert status.success?, "the child takes the lock a gone thread held"
  end

  # A Signal.trap handler cannot take a Mutex on CRuby; its statements run
  # as they did before the lock.
  def test_statements_run_inside_a_signal_trap_handler
    results = run_in_trap_handler do
      [User.create!(name: "Ada").name, User.transaction { User.create!(name: "Bob").name }, User.count]
    end

    assert_equal ["Ada", "Bob", 2], results
    assert_equal %w[Ada Bob], committed_names
    assert_equal 0, depth
  end

  def test_a_signal_trap_handler_inside_a_transaction_joins_it
    names = User.transaction do
      User.create!(name: "Ada")
      run_in_trap_handler do
        User.create!(name: "Bob")
        User.pluck(:name)
      end
    end

    assert_equal %w[Ada Bob], names
    assert_equal %w[Ada Bob], committed_names
    assert_equal 0, depth
  end

  def test_a_signal_trap_handler_does_not_wait_for_another_threads_transaction
    a, finish = open_transaction("Ada")
    count = run_in_trap_handler { User.where(name: "Grace").count }
    a_still_open = a.alive?
    finish << true
    a.join

    assert_equal 0, count
    assert a_still_open, "the handler ran while Ada's transaction was open"
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

  # Opens a transaction on a new thread that writes +name+, holds the
  # connection until +finish+ gets an item, then rolls back.
  def open_transaction(name)
    open = Queue.new
    finish = Queue.new
    thread = Thread.new do
      User.transaction do
        User.create!(name: name)
        open << true
        wait_for(finish, 30)
        raise "#{name} fails"
      end
    rescue RuntimeError
      nil
    end
    open.pop
    [thread, finish]
  end

  # The transaction open_transaction started still holds the connection:
  # Carol's write waits for it, then survives its rollback.
  def assert_still_holds_the_connection(thread, finish)
    carol = Thread.new { User.create!(name: "Carol") }
    wait_until { carol.status == "sleep" || !carol.alive? }
    assert carol.alive?, "Carol waits for the open transaction"
    finish << true
    thread.join
    refute_nil carol.join(10)
    assert_equal ["Carol"], committed_names
  end

  # Starts a thread that takes +lock+ and, still inside ThreadLock#acquire,
  # waits until +interrupt+ has been sent to it. Returns the thread once the
  # interrupt has run its course (the thread rescued it, or died).
  def interrupt_while_taking(lock, &interrupt)
    taken = Queue.new
    sent = Queue.new
    hook = Module.new do
      define_method(:acquire) do
        result = super()
        if Thread.current[:pause_after_acquire]
          taken << true
          sent.pop
        end
        result
      end
      private :acquire
    end
    lock.singleton_class.prepend(hook)
    thread = Thread.new do
      Thread.current.report_on_exception = false
      Thread.current[:pause_after_acquire] = true
      begin
        lock.synchronize { Thread.current[:outcome] = :ran }
      rescue Interrupted
        Thread.current[:outcome] = :interrupted
      end
      sleep
    end
    taken.pop
    interrupt.call(thread)
    sent << true
    wait_until { thread[:outcome] || !thread.alive? }
    thread
  end

  def lock_free?(lock)
    lock.instance_variable_get(:@owner).nil? && lock.instance_variable_get(:@depth).zero?
  end

  # Runs the block in a SIGUSR2 handler and returns its value.
  def run_in_trap_handler(&block)
    skip "no SIGUSR2 here" unless Signal.list.key?("USR2")
    # sqlite3 loads these encodings on its first string bind, which a trap
    # handler cannot do (it warns).
    "".encode("UTF-16LE")
    "".encode("UTF-16BE")
    outcome = nil
    previous = Signal.trap("USR2") do
      outcome = [:ok, block.call]
    rescue Exception => error
      outcome = [:error, error]
    end
    trapped = true
    Process.kill("USR2", Process.pid)
    assert wait_until { outcome }, "the trap handler ran"
    raise outcome[1] if outcome[0] == :error

    outcome[1]
  ensure
    Signal.trap("USR2", previous) if trapped
  end

  # Waits up to +seconds+ for an item on +queue+; true when one came.
  def wait_for(queue, seconds)
    deadline = monotonic_now + seconds
    sleep 0.005 while queue.empty? && monotonic_now < deadline
    !queue.empty?
  end

  # Waits up to +seconds+ for the block to return a true value; returns it.
  def wait_until(seconds = 5)
    deadline = monotonic_now + seconds
    until (value = yield)
      return value if monotonic_now >= deadline

      sleep 0.005
    end
    value
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
