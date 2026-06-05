# frozen_string_literal: true

module Ruflet
  module Rails
    module Protocol
      class LocalServer
        def initialize(session_registry: Ruflet::Rails.sessions, &app_block)
          @app_block = app_block
          @session_registry = session_registry
          @sessions = {}
          @sessions_mutex = Mutex.new
        end

        def handle_upgraded_socket(io)
          ws = WebSocketConnection.new(io)
          run_connection(ws)
        end

        private

        def run_connection(ws)
          while (raw = ws.read_message)
            handle_message(ws, raw)
          end
        rescue StandardError => e
          Rails.logger.error("RUFLET CRASH: #{e.class}: #{e.message}\n#{e.backtrace.first(10).join("\n")}") if defined?(Rails)
          send_message(ws, Ruflet::Protocol::ACTIONS[:session_crashed], { "message" => e.message.to_s.dup.force_encoding("UTF-8") })
        ensure
          close_connection(ws)
        end

        def close_connection(ws)
          return unless ws

          remove_session(ws)
          ws.close
        end

        def remove_session(ws)
          page = @sessions_mutex.synchronize { @sessions.delete(ws.session_key) }
          @session_registry.remove(page.session_id, connection_key: ws.session_key) if page
        end

        def handle_message(ws, raw)
          action, payload = decode_incoming(raw)
          payload ||= {}

          case action
          when Ruflet::Protocol::ACTIONS[:register_client], Ruflet::Protocol::ACTIONS[:register_web_client]
            on_register_client(ws, payload)
          when Ruflet::Protocol::ACTIONS[:control_event], Ruflet::Protocol::ACTIONS[:page_event_from_web]
            on_control_event(ws, payload)
          when Ruflet::Protocol::ACTIONS[:update_control], Ruflet::Protocol::ACTIONS[:update_control_props]
            on_update_control(ws, payload)
          when Ruflet::Protocol::ACTIONS[:invoke_control_method]
            on_invoke_control_method(ws, payload)
          else
            raise "Unknown action: #{action.inspect}"
          end
        end

        def decode_incoming(raw)
          parsed = normalize_incoming(WireCodec.unpack(raw.to_s.b))

          if parsed.is_a?(Array) && parsed.length >= 2
            return [parsed[0], parsed[1]]
          end

          if parsed.is_a?(Hash)
            action = parsed["action"] || parsed[:action]
            payload = parsed["payload"] || parsed[:payload]
            return [action, payload] unless action.nil?

            if (parsed.key?("target") || parsed.key?(:target)) && (parsed.key?("name") || parsed.key?(:name))
              return [Ruflet::Protocol::ACTIONS[:control_event], parsed]
            end
          end

          raise "Unsupported payload format"
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
            value.to_s
          end
        end

        def on_register_client(ws, payload)
          normalized = Ruflet::Protocol.normalize_register_payload(payload)
          session_id = normalized["session_id"].to_s.empty? ? pseudo_uuid : normalized["session_id"]
          existing_session = @session_registry[session_id]
          page = existing_session&.page
          first_registration = page.nil?

          if page
            attach_sender(page, ws)
            reset_mount_state(page)
          else
            page = Ruflet::Page.new(
              session_id: session_id,
              client_details: normalized,
              sender: sender_for(ws)
            )
            page.title = "Ruflet App"
          end

          @sessions_mutex.synchronize { @sessions[ws.session_key] = page }
          @session_registry.add(
            key: page.session_id,
            page: page,
            env: Context.current_env,
            connection_key: ws.session_key
          )

          initial_response = [
            Ruflet::Protocol::ACTIONS[:register_client],
            Ruflet::Protocol.register_response(session_id: session_id)
          ]
          ws.send_binary(WireCodec.pack(initial_response))

          @app_block.call(page) if first_registration
          page.update
        rescue StandardError => e
          send_message(ws, Ruflet::Protocol::ACTIONS[:session_crashed], { "message" => e.message.to_s })
          raise
        end

        def on_control_event(ws, payload)
          event = Ruflet::Protocol.normalize_control_event_payload(payload)
          page = fetch_page(ws)
          return if event["target"].nil? || event["name"].to_s.empty?

          attach_sender(page, ws)
          debug_event(ws, event)
          page.dispatch_event(
            target: event["target"],
            name: event["name"],
            data: normalize_event_data(event["data"])
          )
        end

        def on_update_control(ws, payload)
          update = Ruflet::Protocol.normalize_update_control_payload(payload)
          page = fetch_page(ws)
          return if update["id"].nil?

          attach_sender(page, ws)
          page.apply_client_update(update["id"], update["props"] || {})
        end

        def on_invoke_control_method(ws, payload)
          page = fetch_page(ws)
          attach_sender(page, ws)
          page.handle_invoke_method_result(Ruflet::Protocol.normalize_invoke_method_result_payload(payload))
        end

        def fetch_page(ws)
          page = @sessions_mutex.synchronize { @sessions[ws.session_key] }
          raise "Session not found" unless page

          page
        end

        def normalize_event_data(value)
          case value
          when Hash
            value.each_with_object({}) { |(k, v), out| out[k.to_sym] = normalize_event_data(v) }
          when Array
            value.map { |entry| normalize_event_data(entry) }
          else
            value
          end
        end

        def send_message(ws, action, payload)
          ws.send_binary(WireCodec.pack([action, payload]))
        rescue StandardError
          nil
        end

        def sender_for(ws)
          lambda do |action, msg_payload|
            send_message(ws, action, msg_payload)
          end
        end

        def attach_sender(page, ws)
          page.instance_variable_set(:@sender, sender_for(ws))
        end

        def debug_event(ws, event)
          return unless ENV["RUFLET_RAILS_DEBUG_EVENTS"] == "true"

          warn(
            "[ruflet_rails] event socket=#{ws.session_key} " \
            "target=#{event["target"].inspect} name=#{event["name"].inspect} data=#{event["data"].inspect}"
          )
        end

        def reset_mount_state(page)
          page.instance_variable_set(:@overlay_container_mounted, false)
          page.instance_variable_set(:@dialogs_container_mounted, false)
          page.instance_variable_set(:@services_container_mounted, false)
        end

        def pseudo_uuid
          now = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
          rnd = rand(0..0xffff_ffff)
          "%08x-%04x-%04x-%04x-%012x" % [
            rnd,
            now & 0xffff,
            (now >> 16) & 0xffff,
            (now >> 32) & 0xffff,
            (now >> 48) & 0xffff_ffff_ffff
          ]
        end
      end
    end
  end
end
