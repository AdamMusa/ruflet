# frozen_string_literal: true

module Ruflet
  module UI
    # Tracks the builder whose block is being evaluated, so `Ruflet.text(...)`
    # written inside `Ruflet.column { ... }` appends to that column the way the
    # bare `text(...)` does. Outside every block there is no current builder,
    # and `Ruflet.*` keeps returning a standalone control.
    #
    # Builders push themselves around `instance_eval` and pop in `ensure`, so a
    # block that raises never leaves a stale builder behind. The stack is kept
    # per thread: the server builds each session on its own thread, so one
    # session's block never captures another session's controls. Under mruby,
    # Thread is the Fiber-backed polyfill (ruby_runtime/vm/stdlib/thread.rb),
    # which provides Thread.current and Thread#[] / Thread#[]= per logical
    # thread.
    module BuildScope
      KEY = :ruflet_build_scope

      module_function

      def current
        stack = Thread.current[KEY]
        return nil if stack.nil? || stack.empty?

        stack.last
      end

      def within(builder)
        thread = Thread.current
        stack = thread[KEY]
        if stack.nil?
          stack = []
          thread[KEY] = stack
        end
        stack.push(builder)
        begin
          yield
        ensure
          stack.pop
        end
      end
    end
  end
end
