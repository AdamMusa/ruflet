# frozen_string_literal: true

module Ruflet
  # Presents the embedded runtime bridge through the same connection contract
  # used by the WebSocket transport. The server protocol therefore remains
  # transport-agnostic: only the bytes' path changes.
  class InProcessConnection
    MAX_MESSAGE_BYTES = 16 * 1024 * 1024
    TASK_PUMP_INTERVAL = 0.001
    REQUIRED_BRIDGE_METHODS = %i[
      __bridge_read_nonblock __bridge_write __bridge_close
    ].freeze

    def initialize(bridge: nil)
      @bridge = bridge || default_bridge
      @closed = false
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
    end

    def send_binary(payload)
      raise IOError, "Ruflet in-process connection is closed" if closed?

      @bridge.__bridge_write(checked_bytes(payload))
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

    def checked_bytes(payload)
      bytes = payload.to_s.b
      if bytes.bytesize > MAX_MESSAGE_BYTES
        raise ArgumentError, "Ruflet in-process message exceeds #{MAX_MESSAGE_BYTES} bytes"
      end

      bytes
    end
  end
end
