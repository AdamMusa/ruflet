# frozen_string_literal: true

module RufletRecord
  module Adapters
    # One adapter, and so one SQLite handle, serves every thread of the
    # process. On CRuby a thread holds the connection for each statement and
    # for a whole transaction block, so threads never share a transaction:
    # another thread waits until the block ends. It waits at most the busy
    # `timeout`, but never less than the default, then gets "database is
    # locked", as from a second SQLite connection. A transaction block must
    # not wait for another thread that needs the database.
    class SQLiteAdapter
      DEFAULT_TIMEOUT_MS = 5_000

      attr_reader :database

      def initialize(config)
        @config = normalize_config(config)
        @database = @config[:database]
        @driver = build_driver(@database)
        @transaction_depth = 0
        @lock = build_lock
        configure
      end

      def execute(sql, binds = [])
        @lock.synchronize { @driver.execute(sql, normalize_binds(binds)) }
      rescue StandardError => error
        raise StatementInvalid, error.message
      end

      def execute_batch(sql)
        @lock.synchronize { @driver.execute_batch(sql) }
      rescue StandardError => error
        raise StatementInvalid, error.message
      end

      def select_all(sql, binds = [])
        execute(sql, binds)
      end

      def select_one(sql, binds = [])
        select_all(sql, binds).first
      end

      def select_value(sql, binds = [])
        row = select_one(sql, binds)
        row && row.values.first
      end

      # The row id and change count belong to the statement just run, so no
      # other thread's statement may run in between.
      def insert(sql, binds = [])
        @lock.synchronize do
          execute(sql, binds)
          @driver.last_insert_row_id
        end
      end

      def update(sql, binds = [])
        @lock.synchronize do
          execute(sql, binds)
          @driver.changes
        end
      end
      alias delete update

      # Runs the block in a transaction, or in a savepoint when one is already
      # open. Raising rolls it back. Every other exit commits it: returning
      # normally, `next`, and also `return`, `break` and `throw` out of the
      # block, as Active Record 7.2 does. A thread killed mid-block rolls back.
      # The calling thread holds the connection until the block ends.
      def transaction(&block)
        @lock.synchronize { run_transaction(&block) }
      end

      def run_transaction
        savepoint = SQL.quote_identifier("ruflet_record_#{@transaction_depth}")
        outermost = @transaction_depth.zero?
        # If BEGIN or SAVEPOINT fails, nothing was opened: its own error
        # propagates, and an open outer transaction is left alone.
        execute(outermost ? "BEGIN IMMEDIATE" : "SAVEPOINT #{savepoint}")
        @transaction_depth += 1
        completed = false
        failed = false
        begin
          result = yield
          completed = true
          result
        rescue Exception => error
          failed = true
          @transaction_depth -= 1
          rollback_transaction(outermost, savepoint)
          # `raise error`, not a bare `raise`: in mruby a bare `raise` raises
          # an empty RuntimeError instead of re-raising the current error.
          raise error
        ensure
          # Also reached by a non-local exit, which skips both the code after
          # `yield` and the rescue above.
          unless failed
            @transaction_depth -= 1
            if !completed && aborting_thread?
              rollback_transaction(outermost, savepoint)
            else
              commit_transaction(outermost, savepoint)
            end
          end
        end
      end
      private :run_transaction

      def table_exists?(name)
        !select_value("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1", [name.to_s]).nil?
      end

      def columns(table_name)
        select_all("PRAGMA table_info(#{SQL.quote_identifier(table_name)})").map do |row|
          Column.new(
            row["name"], row["type"], row["notnull"].to_i != 1,
            row["dflt_value"], row["pk"].to_i == 1
          )
        end
      end

      def indexes(table_name)
        select_all("PRAGMA index_list(#{SQL.quote_identifier(table_name)})")
      end

      def close
        @driver.close
      end

      private

      def commit_transaction(outermost, savepoint)
        execute(outermost ? "COMMIT" : "RELEASE SAVEPOINT #{savepoint}")
      rescue Exception => error
        rollback_transaction(outermost, savepoint)
        raise error
      end

      def rollback_transaction(outermost, savepoint)
        if outermost
          execute("ROLLBACK")
        else
          execute("ROLLBACK TO SAVEPOINT #{savepoint}")
          execute("RELEASE SAVEPOINT #{savepoint}")
        end
      end

      # Thread#kill runs ensure blocks but not rescue blocks; its half-done
      # work must not be committed. mruby has no native threads; the VM's
      # cooperative Thread shim never reports "aborting".
      def aborting_thread?
        return false unless Object.const_defined?(:Thread) && Thread.respond_to?(:current)

        thread = Thread.current
        thread.respond_to?(:status) && thread.status == "aborting"
      end

      def normalize_config(config)
        value = config.is_a?(Hash) ? config.dup : { database: config }
        value = value.each_with_object({}) { |(key, item), result| result[key.to_sym] = item }
        database = value[:database]
        raise ArgumentError, "database is required" if database.nil? || database.to_s.empty?
        value[:database] = database.to_s
        value
      end

      def build_driver(path)
        if RufletRecord.const_defined?(:NativeSQLite)
          NativeDriver.new(path)
        else
          CRubyDriver.new(path)
        end
      end

      # mruby's Thread is cooperative (fibers on one native thread), it has no
      # Monitor, and its Mutex is not reentrant, so statements there run
      # unlocked, as they always have.
      #
      # On CRuby a busy `timeout` below the default does not shorten a
      # thread's wait for another thread. Plain statements on two threads
      # overlap all the time, and a waiting thread can go a GVL time slice
      # (100 ms) or longer before it runs, so a short wait would fail them.
      def build_lock
        return NullLock.new if RUBY_ENGINE == "mruby"

        ThreadLock.new([busy_timeout, DEFAULT_TIMEOUT_MS].max)
      end

      def busy_timeout
        @config.fetch(:timeout, DEFAULT_TIMEOUT_MS).to_i
      end

      def configure
        execute("PRAGMA foreign_keys = ON") if @config.fetch(:foreign_keys, true)
        execute("PRAGMA busy_timeout = #{busy_timeout}")
        if @config[:journal_mode]
          mode = @config[:journal_mode].to_s.upcase
          raise ArgumentError, "invalid journal mode" unless %w[DELETE TRUNCATE PERSIST MEMORY WAL OFF].include?(mode)
          execute("PRAGMA journal_mode = #{mode}")
        end
      end

      def normalize_binds(binds)
        binds.map do |value|
          if value == true
            1
          elsif value == false
            0
          elsif value.is_a?(Time)
            # Stored as UTC wall-clock text, which Column#cast reads as UTC.
            value = value.getutc
            "%04d-%02d-%02d %02d:%02d:%02d" % [
              value.year, value.month, value.day,
              value.hour, value.min, value.sec
            ]
          else
            value
          end
        end
      end
    end

    class NativeDriver
      def initialize(path)
        @database = RufletRecord::NativeSQLite::Database.new(path)
      end

      def execute(sql, binds)
        @database.execute(sql, binds)
      end

      def execute_batch(sql)
        @database.execute_batch(sql)
      end

      def changes
        @database.changes
      end

      def last_insert_row_id
        @database.last_insert_row_id
      end

      def close
        @database.close
      end
    end

    # The connection lock on mruby; see SQLiteAdapter#build_lock.
    class NullLock
      def synchronize
        yield
      end
    end

    unless RUBY_ENGINE == "mruby"
      require "sqlite3"

      # The connection lock on CRuby. It is reentrant, so statements inside a
      # transaction block and nested transactions (savepoints) run as before.
      # A thread owns it, not a fiber, so an Enumerator stepped inside a
      # transaction block uses the same connection. A thread that cannot take
      # it within `timeout_ms` gets StatementInvalid. A Signal.trap handler
      # cannot take it (CRuby forbids Mutex#lock there), so a handler's
      # statements run without it, as they did before this lock existed.
      class ThreadLock
        def initialize(timeout_ms)
          @timeout_ms = timeout_ms.to_i < 0 ? 0 : timeout_ms.to_i
          @mutex = Mutex.new
          @released = ConditionVariable.new
          @owner = nil
          @depth = 0
        end

        def synchronize
          acquired = false
          begin
            # Interrupts (Thread#kill, Thread#raise, Timeout) wait until
            # `acquired` is set, so the ensure releases exactly the locks this
            # thread took.
            Thread.handle_interrupt(Object => :never) do
              acquired = acquire
            end
            yield
          ensure
            Thread.handle_interrupt(Object => :never) { release } if acquired
          end
        end

        private

        # Takes the lock and returns true. In a Signal.trap handler, where
        # Mutex#lock raises ThreadError, it takes nothing and returns false.
        def acquire
          begin
            @mutex.lock
          rescue ThreadError
            return false
          end
          begin
            take(Thread.current)
          ensure
            @mutex.unlock
          end
          true
        end

        def take(current)
          if @owner.equal?(current)
            @depth += 1
            return
          end
          deadline = nil
          # A dead owner (a forked child, for one) never releases the lock.
          while @owner && @owner.alive?
            deadline ||= monotonic_now + (@timeout_ms / 1000.0)
            remaining = deadline - monotonic_now
            if remaining <= 0
              raise StatementInvalid,
                    "database is locked (another thread held the connection for over #{@timeout_ms} ms)"
            end
            # A thread that is waiting can still be killed or timed out.
            Thread.handle_interrupt(Object => :on_blocking) { @released.wait(@mutex, remaining) }
          end
          @owner = current
          @depth = 1
        end

        def release
          @mutex.synchronize do
            @depth -= 1
            if @depth.zero?
              @owner = nil
              @released.broadcast
            end
          end
        end

        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end

      class CRubyDriver
        def initialize(path)
          @database = SQLite3::Database.new(path)
          @database.results_as_hash = true
        end

        def execute(sql, binds)
          @database.execute(sql, binds).map do |row|
            normalized = {}
            row.each { |key, value| normalized[key.to_s] = value unless key.is_a?(Integer) }
            normalized
          end
        end

        def execute_batch(sql)
          @database.execute_batch(sql)
          []
        end

        def changes
          @database.changes
        end

        def last_insert_row_id
          @database.last_insert_row_id
        end

        def close
          @database.close
        end
      end
    end
  end
end
