# frozen_string_literal: true

module Ruflet
  # Raised (or recorded, for the WebSocket transport) when a client sends a
  # message larger than the server accepts. It is an ArgumentError so code
  # that rescued the in-process transport's earlier ArgumentError still does.
  class MessageTooLargeError < ArgumentError
    attr_reader :bytes, :limit

    # outgoing: true for a message the server tried to send (the in-process
    # transport). That message is not sent; whether the connection then
    # closes is up to the caller, so the message does not claim it.
    def initialize(bytes:, limit:, outgoing: false)
      @bytes = bytes
      @limit = limit
      what =
        if outgoing
          "a #{bytes}-byte message to the client exceeds the #{limit}-byte limit, so it was not sent"
        else
          "a client message of at least #{bytes} bytes exceeds the #{limit}-byte limit, so the connection was closed"
        end
      super("#{what}; set #{ServerLimits::MAX_MESSAGE_BYTES_ENV} to raise the limit")
    end
  end

  # Limits on what clients may send. The defaults keep every application
  # working as before; the environment variables below adjust them.
  #
  #   RUFLET_MAX_MESSAGE_BYTES  largest message a client may send and,
  #                             over the embedded in-process transport,
  #                             largest message the server sends
  #                             (default 16 MiB, as before)
  #   RUFLET_MAX_CONNECTIONS    most connections handled at once
  #                             (default: unlimited)
  module ServerLimits
    DEFAULT_MAX_MESSAGE_BYTES = 16 * 1024 * 1024
    MAX_MESSAGE_BYTES_ENV = "RUFLET_MAX_MESSAGE_BYTES"
    MAX_CONNECTIONS_ENV = "RUFLET_MAX_CONNECTIONS"

    def self.max_message_bytes
      positive_integer_env(MAX_MESSAGE_BYTES_ENV) || DEFAULT_MAX_MESSAGE_BYTES
    end

    # nil means unlimited.
    def self.max_connections
      positive_integer_env(MAX_CONNECTIONS_ENV)
    end

    def self.positive_integer_env(name)
      return nil unless Object.const_defined?(:ENV)

      raw = ENV[name].to_s.strip
      return nil if raw.empty?

      value = begin
        Integer(raw, 10)
      rescue ArgumentError, TypeError
        nil
      end
      return value if value && value > 0

      warn_invalid(name, raw)
      nil
    end

    def self.warn_invalid(name, raw)
      @warned_invalid ||= {}
      key = "#{name}=#{raw}"
      return if @warned_invalid[key]

      @warned_invalid[key] = true
      warn "Ignoring #{name}=#{raw.inspect}: expected a positive whole number"
    end
  end
end
