# frozen_string_literal: true

module Ruflet
  module Rails
    module Protocol
      # Runs one connection's units of work (each client message, then the
      # disconnect) in the Rails executor, one executor run per unit: the way
      # Rails runs an HTTP request and Action Cable runs a channel command.
      #
      # Holding one executor for the whole WebSocket kept the code-reload
      # interlock shared until the client left (in development, the first
      # request after a code edit hung until then), kept the Active Record
      # query cache on for the whole connection (handlers read stale rows),
      # and kept any leased database connection out of the pool.
      #
      # The executor resets CurrentAttributes and the error/event reporter
      # context when a run completes. A connection used to keep what the app
      # set there (in the entrypoint or a handler) until it disconnected, so
      # that state is carried from each unit to the next and reset once, at
      # the disconnect, as before.
      class Execution
        def self.executor
          return nil unless defined?(::Rails) && ::Rails.respond_to?(:application)

          app = ::Rails.application
          executor = app.executor if app.respond_to?(:executor)
          executor.respond_to?(:wrap) ? executor : nil
        end

        def initialize
          @state = nil
        end

        # One client message. What the app set stays set for the next unit.
        def run(&block)
          perform(keep: true, &block)
        end

        # The disconnect: the last unit. The executor resets the app's state.
        def finish(&block)
          perform(keep: false, &block)
        end

        private

        def perform(keep:)
          executor = self.class.executor
          return yield if executor.nil?
          # Already inside an executor run (an outer wrap owns the state).
          return yield if executor.respond_to?(:active?) && executor.active?

          failure = nil
          result = executor.wrap do
            ExecutionState.restore(@state)
            @state = nil
            begin
              yield
            rescue StandardError => e
              # Re-raised outside the run, so the connection loop handles it
              # (log + session_crashed) as before, and the executor does not
              # also report it to Rails.error as unhandled.
              failure = e
              nil
            ensure
              @state = ExecutionState.detach if keep
            end
          end
          raise failure if failure

          result
        end
      end

      # The per-run state the Rails executor resets: CurrentAttributes
      # instances, ActiveSupport::ExecutionContext (Rails.error.set_context)
      # and, on Rails 8.1+, the event reporter context.
      module ExecutionState
        module_function

        # Takes the state off the current run, so completing the run does not
        # reset it, and returns it for #restore.
        def detach
          {
            current_attributes: detach_current_attributes,
            execution_context: execution_context,
            event_context: event_context
          }
        end

        def restore(state)
          return unless state

          restore_current_attributes(state[:current_attributes])
          context = state[:execution_context]
          ::ActiveSupport::ExecutionContext.set(**context) if context && !context.empty?
          events = state[:event_context]
          ::ActiveSupport.event_reporter.set_context(events) if events && !events.empty?
        end

        def current_attributes_instances
          return nil unless defined?(::ActiveSupport::CurrentAttributes)

          klass = ::ActiveSupport::CurrentAttributes
          return nil unless klass.respond_to?(:current_instances, true)

          instances = klass.send(:current_instances)
          instances.is_a?(Hash) ? instances : nil
        end

        def detach_current_attributes
          instances = current_attributes_instances
          return nil if instances.nil? || instances.empty?

          detached = instances.dup
          instances.clear
          detached
        end

        def restore_current_attributes(detached)
          return if detached.nil? || detached.empty?

          instances = current_attributes_instances
          return unless instances

          detached.each do |key, instance|
            live = live_class(instance.class)
            next unless live

            instances[key] =
              if live.equal?(instance.class)
                instance
              else
                # Development reloaded the class between two messages: carry
                # the values over to an instance of the reloaded class.
                live.new.tap { |fresh| fresh.attributes = fresh.attributes.merge(instance.attributes) }
              end
          end
        end

        def live_class(klass)
          name = klass.name
          return nil if name.nil? || name.empty?

          live = Object.const_get(name)
          live if live.is_a?(Class) && live <= ::ActiveSupport::CurrentAttributes
        rescue StandardError, ScriptError
          nil
        end

        def execution_context
          return nil unless defined?(::ActiveSupport::ExecutionContext)

          ::ActiveSupport::ExecutionContext.to_h
        end

        def event_context
          return nil unless defined?(::ActiveSupport) && ::ActiveSupport.respond_to?(:event_reporter)

          reporter = ::ActiveSupport.event_reporter
          reporter.respond_to?(:context) ? reporter.context : nil
        end
      end
    end
  end
end
