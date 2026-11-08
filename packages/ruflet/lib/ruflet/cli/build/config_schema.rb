# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # Every ruflet.yaml and services.yaml key Ruflet reads, declared by the
      # feature that reads it (one file per feature in config_schema/). It is
      # a list only: nothing validates a project against it yet, so it changes
      # no build. `ruflet check` (CLI-22) will report keys it does not know.
      #
      # A key is a dotted path. The children of a :map are keys of their own
      # and must be registered too; the items of a :list (services,
      # extensions) are free-form. A key that may sit in a platform section is
      # registered with register_platform, which accepts the three spellings
      # platform_build_config merges: `ios.team_id`, `build.ios.team_id` and
      # `assets.ios.team_id`.
      #
      # A feature adding a key registers it beside its code:
      #
      #   ConfigSchema.register("deep_links", type: :map, feature: :deep_links)
      #   ConfigSchema.register("deep_links.schemes", type: :list, feature: :deep_links)
      module ConfigSchema
        FILES = %w[ruflet.yaml services.yaml].freeze
        TYPES = %i[map list string boolean integer path url].freeze
        PLATFORMS = %w[android ios web macos windows linux].freeze
        PLATFORM_SECTION_ROOTS = [nil, "build", "assets"].freeze

        Key = Struct.new(:path, :type, :feature, :description, keyword_init: true)

        class Registry
          def initialize
            @keys = FILES.to_h { |file| [file, {}] }
          end

          # Registering a key again with the same type changes nothing (the
          # first registration keeps its feature and description), so two
          # features reading one key may both declare it.
          def register(path, type:, feature:, description: nil, files: ["ruflet.yaml"])
            raise ArgumentError, "unknown config key type #{type.inspect}" unless TYPES.include?(type)

            files = Array(files)
            unknown = files - FILES
            raise ArgumentError, "unknown config file #{unknown.join(', ')}" unless unknown.empty?

            path = path.to_s
            segments = path.split(".", -1)
            unless !segments.empty? && segments.all? { |segment| segment.match?(/\A[a-z0-9_]+\z/) }
              raise ArgumentError, "invalid config key #{path.inspect}"
            end

            files.map { |file| store(file, path, segments, type, feature, description) }.first
          end

          def register_platform(key, type:, feature:, platforms: PLATFORMS, description: nil, files: ["ruflet.yaml"])
            Array(platforms).flat_map do |platform|
              PLATFORM_SECTION_ROOTS.map do |root|
                register(
                  [root, platform, key].compact.join("."),
                  type: type, feature: feature, description: description, files: files
                )
              end
            end
          end

          def keys(file: "ruflet.yaml", feature: nil)
            entries = @keys.fetch(file).values
            entries = entries.select { |entry| entry.feature == feature } if feature
            entries
          end

          def lookup(path, file: "ruflet.yaml")
            @keys.fetch(file)[path.to_s]
          end

          def known?(path, file: "ruflet.yaml")
            !lookup(path, file: file).nil?
          end

          private

          def store(file, path, segments, type, feature, description)
            keys = @keys.fetch(file)
            existing = keys[path]
            if existing
              return existing if existing.type == type

              raise ArgumentError, "#{file} key #{path} is already registered as #{existing.type}"
            end

            parent = segments[0...-1].join(".")
            unless parent.empty? || keys[parent]&.type == :map
              raise ArgumentError, "#{file} key #{path} needs #{parent} registered as a map first"
            end

            keys[path] = Key.new(path: path, type: type, feature: feature, description: description).freeze
          end
        end

        @registry = Registry.new

        class << self
          attr_reader :registry

          def register(path, type:, feature:, description: nil, files: ["ruflet.yaml"])
            registry.register(path, type: type, feature: feature, description: description, files: files)
          end

          def register_platform(key, type:, feature:, platforms: PLATFORMS, description: nil, files: ["ruflet.yaml"])
            registry.register_platform(
              key, type: type, feature: feature, platforms: platforms, description: description, files: files
            )
          end

          def keys(file: "ruflet.yaml", feature: nil)
            registry.keys(file: file, feature: feature)
          end

          def lookup(path, file: "ruflet.yaml")
            registry.lookup(path, file: file)
          end

          def known?(path, file: "ruflet.yaml")
            registry.known?(path, file: file)
          end
        end
      end
    end
  end
end
