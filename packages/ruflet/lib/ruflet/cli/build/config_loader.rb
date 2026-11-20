# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # Reads ruflet.yaml (or RUFLET_CONFIG) and services.yaml, and the lookups
      # every feature uses to read a key from them.
      module ConfigLoader
        # Clients that are told which server to use at launch rather than at build
        # time, so they may be built without a configured backend_url.
        RUNTIME_RESOLVED_BACKEND_PLATFORMS = %w[web macos windows linux].freeze

        private

        def configured_backend_url(config)
          candidates = [
            config["backend_url"],
            config["server_url"],
            config["ruflet_client_url"],
            (config["app"].is_a?(Hash) ? config["app"]["backend_url"] : nil),
            (config["app"].is_a?(Hash) ? config["app"]["server_url"] : nil),
            (config["app"].is_a?(Hash) ? config["app"]["ruflet_client_url"] : nil)
          ]
          raw = candidates.find { |v| !v.to_s.strip.empty? }
          return nil if raw.nil?

          value = raw.to_s.strip
          uri = URI.parse(value)
          return nil unless %w[http https ws wss].include?(uri.scheme)
          return nil if uri.host.to_s.strip.empty?

          value
        rescue URI::InvalidURIError
          nil
        end

        def load_ruflet_config
          config_path = ENV["RUFLET_CONFIG"] || "ruflet.yaml"
          unless File.file?(config_path)
            alt = "ruflet.yml"
            config_path = alt if File.file?(alt)
          end
          config_exists = File.file?(config_path)
          config = config_exists ? YAML.safe_load(read_text_file(config_path), aliases: true) || {} : {}
          config_dir = File.dirname(File.expand_path(config_path))
          services_path = File.join(config_dir, "services.yaml")
          if File.file?(services_path)
            service_config = YAML.safe_load(read_text_file(services_path), aliases: true) || {}
            if service_config["app"].is_a?(Hash)
              # ruflet.yaml declares the app; services.yaml may still carry an
              # identity from older projects, so it fills gaps rather than
              # overriding what the project states.
              declared = config["app"].is_a?(Hash) ? config["app"] : {}
              config["app"] = service_config["app"].merge(declared)
            end
            config["services"] = service_config["services"] if service_config.key?("services")
          end
          config
        rescue StandardError => e
          warn "Failed to load ruflet config: #{e.class}: #{e.message}"
          {}
        end

        # Platform-specific overrides may live in a top-level `<platform>:` block,
        # under `build.<platform>:`, or under `assets.<platform>:`. Later sources win.
        def platform_build_config(config, platform)
          name = platform.to_s
          build = config["build"].is_a?(Hash) ? config["build"] : {}
          assets = config["assets"].is_a?(Hash) ? config["assets"] : {}
          [config[name], build[name], assets[name]].each_with_object({}) do |source, merged|
            next unless source.is_a?(Hash)

            source.each { |key, value| merged[key.to_s] = value }
          end
        end

        # Like first_present, but keeps `false` — needed for boolean toggles.
        def first_defined(hash, *keys)
          return nil unless hash.is_a?(Hash)

          keys.each do |key|
            return hash[key] if hash.key?(key)
            return hash[key.to_sym] if hash.key?(key.to_sym)
          end
          nil
        end

        def first_present(*values)
          values.find { |value| !value.to_s.strip.empty? }
        end

        def key_defined?(hash, key)
          hash.is_a?(Hash) && (hash.key?(key) || hash.key?(key.to_sym))
        end
      end
    end
  end
end
