# frozen_string_literal: true

require "thread"

module Ruflet
  module Rails
    class Session
      attr_reader :key, :page, :env, :connected_at, :connection_key

      def initialize(key:, page:, env: nil, connected_at: Time.now, connection_key: nil)
        @key = key
        @page = page
        @env = env
        @connected_at = connected_at
        @connection_key = connection_key
      end

      def session_id
        page.session_id
      end

      def client_details
        page.client_details
      end
    end

    class SessionRegistry
      include Enumerable

      def initialize
        @sessions = {}
        @mutex = Mutex.new
      end

      def add(key:, page:, env: nil, connection_key: nil)
        session = Session.new(key: key, page: page, env: env, connection_key: connection_key)
        @mutex.synchronize { @sessions[key] = session }
        session
      end

      def remove(key, connection_key: nil)
        @mutex.synchronize do
          session = @sessions[key]
          return nil if connection_key && session&.connection_key && session.connection_key != connection_key

          @sessions.delete(key)
        end
      end

      def [](key)
        @mutex.synchronize { @sessions[key] }
      end

      def each(&block)
        return enum_for(:each) unless block

        snapshot.each(&block)
      end

      def size
        @mutex.synchronize { @sessions.size }
      end

      def empty?
        size.zero?
      end

      def clear
        @mutex.synchronize { @sessions.clear }
      end

      def pages
        map(&:page)
      end

      def broadcast(&block)
        raise ArgumentError, "Ruflet::Rails.broadcast requires a block" unless block

        count = 0
        each do |session|
          block.arity == 1 ? block.call(session.page) : block.call(session.page, session)
          count += 1
        end
        count
      end

      private

      def snapshot
        @mutex.synchronize { @sessions.values.dup }
      end
    end
  end
end
