# frozen_string_literal: true

module Ruflet
  # Transport-agnostic implementation of the Ruflet wire protocol: one
  # connection loop shared by every server that speaks to Flutter clients.
  #
  # The standalone TCP server (Ruflet::Server) and host-server adapters such
  # as ruflet_rails' Rack-hijack endpoint include this module and provide
  # only their transport plus the integration hooks below — the protocol
  # itself is never reimplemented.
  #
  # Includers must initialize:
  #   @app_block       — proc invoked with the Page on first registration
  #   @sessions        — Hash mapping connection key => Page
  #   @sessions_mutex  — Mutex guarding @sessions
  module ConnectionProtocol
    # ------------------------------------------------------------------
    # Integration hooks (override in the including server as needed).
    # ------------------------------------------------------------------

    # Called when a connection enters the protocol loop.
    def connection_opened(ws); end

    # Called when a connection leaves the protocol loop.
    def connection_closed(ws); end

    # Return an existing Page to resume for this session id, or nil to
    # create a fresh one (hosts with a session registry override this).
    def resume_session(_session_id)
      nil
    end

    # Called after a Page is stored for a connection.
    def session_stored(page, ws); end

    # Called after a Page is removed for a connection.
    def session_removed(page, ws); end

    # Called before a control event is dispatched to the Page.
    def before_dispatch_event(ws, event); end

    def log_connection_error(error)
      warn "server error: #{error.class}: #{error.message}"
      warn error.backtrace.join("\n") if error.backtrace
    end

    # ------------------------------------------------------------------
    # Transport entry points.
    # ------------------------------------------------------------------

    # For hosts that already performed the HTTP upgrade (Rack hijack, the
    # embedded runtime, tests with socket pairs).
    def handle_upgraded_socket(io)
      run_connection(Ruflet::WebSocketConnection.new(io))
    end

    def run_connection(ws)
      connection_opened(ws)

      while (raw = ws.read_message)
        handle_message(ws, raw)
      end
    rescue StandardError => e
      return if disconnect_error?(e)

      log_connection_error(e)
      send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message.to_s.dup.force_encoding("UTF-8") })
    ensure
      close_connection(ws)
    end

    def close_connection(ws)
      return unless ws

      remove_session(ws)
      connection_closed(ws)
      ws.close
    end

    # ------------------------------------------------------------------
    # Protocol core.
    # ------------------------------------------------------------------

    def handle_message(ws, raw)
      action, payload = decode_incoming(raw)
      payload ||= {}

      warn "incoming action=#{action.inspect}" if ENV["RUFLET_DEBUG"] == "1"

      case action
      when Protocol::ACTIONS[:register_client], Protocol::ACTIONS[:register_web_client]
        on_register_client(ws, payload)
      when Protocol::ACTIONS[:control_event], Protocol::ACTIONS[:page_event_from_web]
        on_control_event(ws, payload)
      when Protocol::ACTIONS[:update_control], Protocol::ACTIONS[:update_control_props]
        on_update_control(ws, payload)
      when Protocol::ACTIONS[:invoke_control_method]
        on_invoke_control_method(ws, payload)
      else
        raise "Unknown action: #{action.inspect}"
      end
    end

    def decode_incoming(raw)
      parsed = normalize_incoming(Ruflet::WireCodec.unpack(raw.to_s.b))

      if parsed.is_a?(Array) && parsed.length >= 2
        return [parsed[0], parsed[1]]
      end

      if parsed.is_a?(Hash)
        action = parsed["action"] || parsed[:action]
        payload = parsed["payload"] || parsed[:payload]
        return [action, payload] unless action.nil?

        if (parsed.key?("target") || parsed.key?(:target)) && (parsed.key?("name") || parsed.key?(:name))
          return [Protocol::ACTIONS[:control_event], parsed]
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
      normalized = Protocol.normalize_register_payload(payload)
      session_id = normalized["session_id"].to_s.empty? ? pseudo_uuid : normalized["session_id"]

      page = resume_session(session_id)
      first_registration = page.nil?

      if page
        attach_sender(page, ws)
        reset_mount_state(page)
      else
        page = Page.new(
          session_id: session_id,
          client_details: normalized,
          sender: sender_for(ws)
        )
        page.title = "Ruflet App"
      end

      @sessions_mutex.synchronize { @sessions[ws.session_key] = page }
      session_stored(page, ws)

      initial_response = [
        Protocol::ACTIONS[:register_client],
        Protocol.register_response(session_id: session_id)
      ]
      ws.send_binary(Ruflet::WireCodec.pack(initial_response))

      @app_block.call(page) if first_registration
      page.update
    rescue StandardError => e
      send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message.to_s })
      raise
    end

    def on_control_event(ws, payload)
      event = Protocol.normalize_control_event_payload(payload)
      page = fetch_page(ws)
      return if event["target"].nil? || event["name"].to_s.empty?

      attach_sender(page, ws)
      before_dispatch_event(ws, event)
      page.dispatch_event(
        target: event["target"],
        name: event["name"],
        data: normalize_event_data(event["data"])
      )
    end

    def on_update_control(ws, payload)
      update = Protocol.normalize_update_control_payload(payload)
      page = fetch_page(ws)
      return if update["id"].nil?

      attach_sender(page, ws)
      page.apply_client_update(update["id"], update["props"] || {})
    end

    def on_invoke_control_method(ws, payload)
      page = fetch_page(ws)
      attach_sender(page, ws)
      page.handle_invoke_method_result(Protocol.normalize_invoke_method_result_payload(payload))
    end

    def fetch_page(ws)
      page = @sessions_mutex.synchronize { @sessions[ws.session_key] }
      raise "Session not found" unless page

      page
    end

    def remove_session(ws)
      return unless ws

      page = @sessions_mutex.synchronize { @sessions.delete(ws.session_key) }
      session_removed(page, ws) if page
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
      return if ws.nil? || ws.closed?

      ws.send_binary(Ruflet::WireCodec.pack([action, payload]))
    rescue StandardError => e
      log_connection_error(e) unless disconnect_error?(e)
      remove_session(ws)
      connection_closed(ws)
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

    def reset_mount_state(page)
      page.instance_variable_set(:@overlay_container_mounted, false)
      page.instance_variable_set(:@dialogs_container_mounted, false)
      page.instance_variable_set(:@services_container_mounted, false)
    end

    def disconnect_error?(error)
      return true if error.is_a?(IOError)
      return true if error.is_a?(Errno::EPIPE)
      return true if error.is_a?(Errno::ECONNRESET)
      return true if error.is_a?(Errno::ECONNABORTED)
      return true if error.is_a?(Errno::ENOTCONN)
      return true if error.is_a?(Errno::ESHUTDOWN)
      return true if error.is_a?(Errno::EBADF)
      return true if error.is_a?(Errno::EINVAL)

      false
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
