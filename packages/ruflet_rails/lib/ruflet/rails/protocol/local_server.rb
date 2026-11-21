# frozen_string_literal: true

require "ruflet_server"

module Ruflet
  module Rails
    module Protocol
      # Thin adapter that runs the shared Ruflet wire protocol
      # (Ruflet::ConnectionProtocol) on sockets hijacked from the Rails
      # server itself — Puma's threads and process model do the scaling,
      # and there is no second server implementation to maintain.
      #
      # The Rails-specific behavior lives entirely in the hooks below:
      # session resumption through the Rails session registry, Rails
      # logging, request-env capture for the registry, and running each
      # message in the Rails executor (see Execution).
      class LocalServer
        include Ruflet::ConnectionProtocol

        # Seconds; Ruflet::Rails.config.session_resume_probe_timeout's default.
        RESUME_PROBE_TIMEOUT = 1.0

        def initialize(session_registry: Ruflet::Rails.sessions, &app_block)
          @app_block = app_block
          @session_registry = session_registry
          @sessions = {}
          @sessions_mutex = Mutex.new
          @executions = {}
          @executions_mutex = Mutex.new
        end

        # Endpoint leaves the Rails executor to this server: one run per
        # message, not one for the socket's whole life.
        def runs_messages_in_rails_executor?
          true
        end

        # -- Rails executor: one run per unit of work --------------------

        def handle_message(ws, raw)
          execution_for(ws).run { super }
        end

        def close_connection(ws)
          return super unless ws

          execution = @executions_mutex.synchronize { @executions.delete(ws.session_key) }
          (execution || Execution.new).finish { super }
        end

        # -- ConnectionProtocol hooks ------------------------------------

        def resume_session(session_id)
          @session_registry[session_id]&.page
        end

        # A client may resume a session only when no other live socket owns
        # it and the app's session_resume_guard (if any) agrees. Otherwise it
        # gets a fresh session under a new id.
        def allow_resume?(session_id, ws)
          session = @session_registry[session_id]
          return true unless session
          return false unless resume_guard_allows?(session)

          !owned_by_another_live_socket?(session, ws)
        end

        def session_stored(page, ws)
          @session_registry.add(
            key: page.session_id,
            page: page,
            env: Context.current_env,
            connection_key: ws.session_key,
            connection: ws
          )
        end

        def session_removed(page, ws)
          @session_registry.remove(page.session_id, connection_key: ws.session_key)
        end

        def before_dispatch_event(ws, event)
          return unless ENV["RUFLET_RAILS_DEBUG_EVENTS"] == "true"

          warn(
            "[ruflet_rails] event socket=#{ws.session_key} " \
            "target=#{event["target"].inspect} name=#{event["name"].inspect} data=#{event["data"].inspect}"
          )
        end

        def log_connection_error(error)
          if defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
            ::Rails.logger.error(
              "RUFLET CRASH: #{error.class}: #{error.message}\n#{Array(error.backtrace).first(10).join("\n")}"
            )
          else
            super
          end
        end

        private

        def resume_guard_allows?(session)
          guard = rails_config&.session_resume_guard
          return true unless guard

          guard.call(session.env, Context.current_env) ? true : false
        rescue StandardError => e
          log_connection_error(e)
          false
        end

        # The owner answering a ping means a second live client presents its
        # id. A closed owner, one that does not answer in time, or one that
        # cannot be pinged is treated as the dropped connection of the
        # reconnecting client.
        def owned_by_another_live_socket?(session, ws)
          owner = session.connection
          return false if owner.nil? || owner.equal?(ws) || owner.closed?
          return false unless owner.respond_to?(:ping)

          timeout = rails_config ? rails_config.session_resume_probe_timeout : RESUME_PROBE_TIMEOUT
          return false unless timeout && timeout.to_f.positive?

          owner.ping(timeout: timeout.to_f) == true
        end

        def rails_config
          Ruflet::Rails.config if Ruflet::Rails.respond_to?(:config)
        end

        def execution_for(ws)
          @executions_mutex.synchronize { @executions[ws.session_key] ||= Execution.new }
        end
      end
    end
  end
end
