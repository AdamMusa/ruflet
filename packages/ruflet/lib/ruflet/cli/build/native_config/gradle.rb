# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module NativeConfig
        # Writes the Gradle inputs of the Android host: android/key.properties.
        module Gradle
          ANDROID_SIGNING_KEYS = {
            "storeFile" => "RUFLET_ANDROID_KEYSTORE",
            "storePassword" => "RUFLET_ANDROID_KEYSTORE_PASSWORD",
            "keyAlias" => "RUFLET_ANDROID_KEY_ALIAS",
            "keyPassword" => "RUFLET_ANDROID_KEY_PASSWORD"
          }.freeze

          private

          # Release signing is read from the project, never from the managed client,
          # so nobody has to edit build/client by hand. Either keep an
          # android/key.properties beside the app, or set the RUFLET_ANDROID_*
          # variables. Without one of those, Gradle falls back to the debug key.
          def apply_android_signing_config(client_dir, platform, verbose: false)
            return unless %w[apk android aab appbundle].include?(platform.to_s)

            android_dir = File.join(client_dir, "android")
            return unless Dir.exist?(android_dir)

            destination = File.join(android_dir, "key.properties")
            properties = android_signing_properties
            if properties.empty?
              File.delete(destination) if File.file?(destination)
              build_note("No Android signing configured; the release build will use the debug key")
              return
            end

            missing = ANDROID_SIGNING_KEYS.keys - properties.keys
            unless missing.empty?
              warn "build config error: Android signing is missing #{missing.join(', ')}"
              warn "Set them in android/key.properties or the matching RUFLET_ANDROID_* variables."
              return
            end

            body = ANDROID_SIGNING_KEYS.keys.map { |key| "#{key}=#{properties.fetch(key)}" }.join("\n")
            write_text_file(destination, "#{body}\n")
            build_log(verbose, "wrote #{destination}")
            build_note("Android release signing configured from #{properties.fetch("_source")}")
          end

          def android_signing_properties
            from_env = ANDROID_SIGNING_KEYS.each_with_object({}) do |(key, variable), out|
              value = ENV[variable].to_s.strip
              out[key] = value unless value.empty?
            end
            unless from_env.empty?
              from_env["storeFile"] = File.expand_path(from_env["storeFile"]) if from_env["storeFile"]
              return from_env.merge("_source" => "the RUFLET_ANDROID_* environment")
            end

            source = project_android_key_properties_path
            return {} unless source

            parsed = read_text_file(source).each_line.with_object({}) do |line, out|
              next if line.strip.empty? || line.strip.start_with?("#")

              key, value = line.split("=", 2)
              out[key.to_s.strip] = value.to_s.strip unless value.nil?
            end
            return {} if parsed.empty?

            # storeFile is written relative to the project; the client sits deeper.
            if parsed["storeFile"] && !Pathname.new(parsed["storeFile"]).absolute?
              parsed["storeFile"] = File.expand_path(parsed["storeFile"], File.dirname(source))
            end
            parsed.merge("_source" => source)
          end

          def project_android_key_properties_path
            [
              File.join(Dir.pwd, "android", "key.properties"),
              File.join(Dir.pwd, "key.properties")
            ].find { |path| File.file?(path) }
          end
        end
      end
    end
  end
end
