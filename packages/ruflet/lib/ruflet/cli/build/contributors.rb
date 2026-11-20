# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # The steps that write a build's configuration into build/client, in the
      # order they run, before Flutter does anything.
      #
      # A contributor is a private build method that takes the build's Context
      # and returns true to continue; anything else stops the build. Each
      # contributor file registers itself, and build_command.rb loads them in
      # run order. A feature adds its own step with `register`, using `before:`
      # or `after:` when the end of the list is not the right place:
      #
      #   Contributors.register(:native_overlay, :contribute_native_overlay)
      #   Contributors.register(:deep_links, :contribute_deep_links, before: :assets)
      module Contributors
        Entry = Struct.new(:name, :handler)

        class Registry
          def initialize
            @entries = []
          end

          # Registering the same name and handler again changes nothing, so a
          # reloaded file cannot duplicate its step.
          def register(name, handler, before: nil, after: nil)
            raise ArgumentError, "pass before: or after:, not both" if before && after

            name = name.to_sym
            handler = handler.to_sym
            existing = @entries.find { |entry| entry.name == name }
            if existing
              return existing if existing.handler == handler

              raise ArgumentError, "build contributor #{name} is already registered"
            end

            index =
              if before
                position(before)
              elsif after
                position(after) + 1
              else
                @entries.length
              end
            entry = Entry.new(name, handler).freeze
            @entries.insert(index, entry)
            entry
          end

          def entries
            @entries.dup.freeze
          end

          def names
            @entries.map(&:name)
          end

          private

          def position(name)
            index = @entries.index { |entry| entry.name == name.to_sym }
            raise ArgumentError, "unknown build contributor #{name}" unless index

            index
          end
        end

        @registry = Registry.new

        class << self
          attr_reader :registry

          def register(name, handler, before: nil, after: nil)
            registry.register(name, handler, before: before, after: after)
          end

          def entries
            registry.entries
          end

          def names
            registry.names
          end
        end
      end
    end
  end
end
