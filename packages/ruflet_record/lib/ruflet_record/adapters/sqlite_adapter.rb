# frozen_string_literal: true

module RufletRecord
  module Adapters
    class SQLiteAdapter
      attr_reader :database

      def initialize(config)
        @config = normalize_config(config)
        @database = @config[:database]
        @driver = build_driver(@database)
        @transaction_depth = 0
        configure
      end

      def execute(sql, binds = [])
        @driver.execute(sql, normalize_binds(binds))
      rescue StandardError => error
        raise StatementInvalid, error.message
      end

      def execute_batch(sql)
        @driver.execute_batch(sql)
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

      def insert(sql, binds = [])
        execute(sql, binds)
        @driver.last_insert_row_id
      end

      def update(sql, binds = [])
        execute(sql, binds)
        @driver.changes
      end
      alias delete update

      # Runs the block in a transaction, or in a savepoint when one is already
      # open. Raising rolls it back. Every other exit commits it: returning
      # normally, `next`, and also `return`, `break` and `throw` out of the
      # block, as Active Record 7.2 does. A thread killed mid-block rolls back.
      def transaction
        savepoint = SQL.quote_identifier("ruflet_record_#{@transaction_depth}")
        outermost = @transaction_depth.zero?
        # If BEGIN or SAVEPOINT fails, nothing was opened: its own error
        # propagates, and an open outer transaction is left alone.
        execute(outermost ? "BEGIN IMMEDIATE" : "SAVEPOINT #{savepoint}")
        @transaction_depth += 1
        failed = false
        begin
          yield
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
            if aborting_thread?
              rollback_transaction(outermost, savepoint)
            else
              commit_transaction(outermost, savepoint)
            end
          end
        end
      end

      def table_exists?(name)
        !select_value("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1", [name.to_s]).nil?
      end

      def columns(table_name)
        select_all("PRAGMA table_info(#{SQL.quote_identifier(table_name)})").map do |row|
          Column.new(
            row["name"], row["type"], row["notnull"].to_i == 1,
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

      def configure
        execute("PRAGMA foreign_keys = ON") if @config.fetch(:foreign_keys, true)
        timeout = @config.fetch(:timeout, 5_000).to_i
        execute("PRAGMA busy_timeout = #{timeout}")
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

    unless RUBY_ENGINE == "mruby"
      require "sqlite3"

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
