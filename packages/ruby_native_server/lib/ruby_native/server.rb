# frozen_string_literal: true

require "json"
require "securerandom"
require "msgpack"

begin
  require "eventmachine"
rescue LoadError
  warn "eventmachine C extension unavailable; falling back to pure Ruby reactor"
  require "em/pure_ruby"
end

require "em-websocket"
require "ruby_native_protocol"
require "ruby_native_ui"

module RubyNative
  class Server
    def initialize(host: "0.0.0.0", port: 8550, &app_block)
      @host = host
      @port = port
      @app_block = app_block
      @sessions = {}
    end

    def start
      previous_int = Signal.trap("INT") do
        EventMachine.stop_event_loop if EventMachine.reactor_running?
      end
      previous_term = Signal.trap("TERM") do
        EventMachine.stop_event_loop if EventMachine.reactor_running?
      end

      EventMachine.run do
        EventMachine.error_handler do |e|
          warn "eventmachine error: #{e.class}: #{e.message}"
          warn e.backtrace.join("\n") if e.backtrace
        end

        EventMachine::WebSocket.start(host: @host, port: @port, path: "/ws") do |ws|
          ws.onmessage do |raw|
            handle_message(ws, raw)
          rescue Exception => e
            warn "server error: #{e.class}: #{e.message}"
            warn e.backtrace.join("\n") if e.backtrace
            send_message(
              ws,
              Protocol::ACTIONS[:session_crashed],
              { "message" => e.message.to_s.dup.force_encoding("UTF-8") }
            )
          end

          ws.onbinary do |raw|
            handle_message(ws, raw)
          rescue Exception => e
            warn "server error: #{e.class}: #{e.message}"
            warn e.backtrace.join("\n") if e.backtrace
            send_message(
              ws,
              Protocol::ACTIONS[:session_crashed],
              { "message" => e.message.to_s.dup.force_encoding("UTF-8") }
            )
          end

          ws.onclose do
            @sessions.delete(ws.object_id)
          end
        end

        unless ENV["RUBY_NATIVE_SUPPRESS_SERVER_BANNER"] == "1"
          warn "RubyNative server listening on ws://#{@host}:#{@port}/ws"
        end
      end
    rescue Interrupt
      # Allow clean Ctrl+C shutdown without printing an exception backtrace.
      nil
    ensure
      Signal.trap("INT", previous_int) if previous_int
      Signal.trap("TERM", previous_term) if previous_term
    end

    private

    def handle_message(ws, raw)
      action, payload = decode_incoming(raw)
      payload ||= {}

      warn "incoming action=#{action.inspect}" if ENV["FLET_DEBUG"] == "1"

      case action
      when Protocol::ACTIONS[:register_client], Protocol::ACTIONS[:register_web_client]
        on_register_client(ws, payload)
      when Protocol::ACTIONS[:control_event], Protocol::ACTIONS[:page_event_from_web]
        on_control_event(ws, payload)
      when Protocol::ACTIONS[:update_control], Protocol::ACTIONS[:update_control_props]
        # Client-side optimistic updates. No-op for now.
      else
        raise "Unknown action: #{action.inspect}"
      end
    end

    def decode_incoming(raw)
      if raw.is_a?(String) || raw.respond_to?(:to_str)
        bytes = (raw.is_a?(String) ? raw : raw.to_str).b

        begin
          parsed = MessagePack.unpack(bytes, allow_unknown_ext: true)
          parsed = normalize_incoming(parsed)

          if parsed.is_a?(Array) && parsed.length >= 2
            return [parsed[0], parsed[1]]
          end

          if parsed.is_a?(Hash)
            action = parsed["action"] || parsed[:action]
            payload = parsed["payload"] || parsed[:payload]
            return [action, payload] unless action.nil?

            # Some clients may send direct event payloads without wrapper action.
            if (parsed.key?("target") || parsed.key?(:target)) && (parsed.key?("name") || parsed.key?(:name))
              return [Protocol::ACTIONS[:control_event], parsed]
            end
          end
        rescue StandardError
          # fall through to JSON for legacy text clients
        end

        msg = JSON.parse(raw.to_s)
        return [msg["action"], normalize_incoming(msg["payload"])]
      end

      raise "Unsupported message type: #{raw.class}"
    end

    def normalize_incoming(value)
      case value
      when String
        value.dup.force_encoding("UTF-8")
      when Integer, Float, TrueClass, FalseClass, NilClass
        value
      when Symbol
        value.to_s
      when Array
        value.map { |v| normalize_incoming(v) }
      when Hash
        value.each_with_object({}) do |(k, v), out|
          out[k.to_s] = normalize_incoming(v)
        end
      else
        # MessagePack extension values (e.g. timestamp) are not needed by runtime logic.
        value.to_s
      end
    end

    def on_register_client(ws, payload)
      normalized = Protocol.normalize_register_payload(payload)
      session_id = normalized["session_id"].to_s.empty? ? SecureRandom.uuid : normalized["session_id"]

      page = Page.new(
        session_id: session_id,
        client_details: normalized,
        sender: lambda { |action, msg_payload|
          send_message(ws, action, msg_payload)
        }
      )

      @sessions[ws.object_id] = { page: page }

      send_message(ws, Protocol::ACTIONS[:register_client], Protocol.register_response(session_id: session_id))

      @app_block&.call(page)
    end

    def on_control_event(ws, payload)
      session = @sessions[ws.object_id]
      return unless session

      if payload.key?("target")
        session[:page].dispatch_event(
          target: payload["target"],
          name: payload["name"],
          data: payload["data"]
        )
      else
        session[:page].dispatch_event(
          target: payload["eventTarget"],
          name: payload["eventName"],
          data: payload["eventData"]
        )
      end
    end

    def send_message(ws, action, payload)
      packet = Protocol.pack_message(action: action, payload: normalize_for_wire(payload))
      ws.send_binary(MessagePack.pack(packet))
    rescue Exception => e
      warn "send error: #{e.class}: #{e.message}"
    end

    def normalize_for_wire(value)
      case value
      when String, Integer, Float, TrueClass, FalseClass, NilClass
        value
      when Symbol
        value.to_s
      when Array
        value.map { |v| normalize_for_wire(v) }
      when Hash
        value.each_with_object({}) do |(k, v), out|
          out[k.to_s] = normalize_for_wire(v)
        end
      else
        # Avoid MessagePack extension values that Dart decoder doesn't support.
        value.to_s
      end
    end
  end
end
