# frozen_string_literal: true

require_relative "limits"

module Ruflet
  # Presents the embedded runtime bridge through the same connection contract
  # used by the WebSocket transport. The server protocol therefore remains
  # transport-agnostic: only the bytes' path changes.
  class InProcessConnection
    # The default; RUFLET_MAX_MESSAGE_BYTES changes it.
    MAX_MESSAGE_BYTES = ServerLimits::DEFAULT_MAX_MESSAGE_BYTES
    TASK_PUMP_INTERVAL = 0.001
    REQUIRED_BRIDGE_METHODS = %i[
      __bridge_read_nonblock __bridge_write __bridge_close
    ].freeze

    attr_reader :max_message_bytes

    # The Ruflet::MessageTooLargeError read_message raised for an oversized
    # incoming message, or nil.
    attr_reader :message_limit_error

    def initialize(bridge: nil, max_message_bytes: nil)
      @bridge = bridge || default_bridge
      @closed = false
      @max_message_bytes = max_message_bytes || ServerLimits.max_message_bytes
      @message_limit_error = nil
      validate_bridge!
    end

    def session_key
      @session_key ||= object_id
    end

    def closed?
      @closed
    end

    def read_message
      return nil if closed?

      payload = wait_for_message
      if payload.nil?
        @closed = true
        return nil
      end

      checked_bytes(payload)
    rescue MessageTooLargeError => e
      @message_limit_error = e
      raise e
    end

    def send_binary(payload)
      raise IOError, "Ruflet in-process connection is closed" if closed?

      @bridge.__bridge_write(checked_bytes(payload, outgoing: true))
    end

    def send_text(payload)
      send_binary(payload)
    end

    def close
      return if closed?

      @closed = true
      @bridge.__bridge_close
    end

    private

    def default_bridge
      Object.const_get(:RubyRuntime)
    rescue NameError
      raise RuntimeError, "Ruflet in-process transport requires the embedded RubyRuntime bridge"
    end

    def validate_bridge!
      missing = REQUIRED_BRIDGE_METHODS.reject { |method_name| @bridge.respond_to?(method_name) }
      return if missing.empty?

      raise RuntimeError, "Ruflet in-process bridge is missing: #{missing.join(', ')}"
    end

    def wait_for_message
      loop do
        payload = @bridge.__bridge_read_nonblock
        return payload unless payload == false

        Thread.pass if Thread.respond_to?(:cooperative?) && Thread.cooperative?
        sleep TASK_PUMP_INTERVAL
      end
    end

    def checked_bytes(payload, outgoing: false)
      bytes = payload.to_s.b
      if bytes.bytesize > @max_message_bytes
        raise MessageTooLargeError.new(bytes: bytes.bytesize, limit: @max_message_bytes, outgoing: outgoing)
      end

      bytes
    end
  end
end
