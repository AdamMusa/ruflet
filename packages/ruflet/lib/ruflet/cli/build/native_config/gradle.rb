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

          # What java_properties_escape writes for each character
          # Properties#load would misread.
          JAVA_PROPERTIES_ESCAPES = { "\\" => "\\\\", "\n" => "\\n", "\r" => "\\r" }.freeze
          JAVA_PROPERTIES_LEADING_BLANKS = { " " => "\\ ", "\t" => "\\t", "\f" => "\\f" }.freeze
          private_constant :JAVA_PROPERTIES_ESCAPES, :JAVA_PROPERTIES_LEADING_BLANKS

          private

          # Release signing is read from the project, never from the managed client,
          # so nobody has to edit build/client by hand. Either keep an
          # android/key.properties beside the app, or set the RUFLET_ANDROID_*
          # variables. Without one of those, Gradle falls back to the debug key.
          #
          # Returns false for a partial configuration, which fails the build like
          # every other build config error. It used to warn and carry on, and
          # Gradle signed with whatever key.properties an earlier build had left
          # in the client (or the debug key).
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
              # Name the source: once one RUFLET_ANDROID_* variable is set, the
              # environment replaces android/key.properties entirely.
              warn "build config error: Android signing from #{properties.fetch("_source")} is missing #{missing.join(', ')}"
              warn "Set them in android/key.properties or the matching RUFLET_ANDROID_* variables."
              return false
            end

            body = ANDROID_SIGNING_KEYS.keys.map { |key| "#{key}=#{properties.fetch(key)}" }.join("\n")
            write_android_key_properties(destination, "#{body}\n")
            build_log(verbose, "wrote #{destination}")
            build_note("Android release signing configured from #{properties.fetch("_source")}")
          end

          # The file holds the signing passwords in plain text, so only the
          # owner may read it: it is created that way, and the mode is reset on
          # a file an earlier build left behind.
          def write_android_key_properties(destination, content)
            File.open(destination, File::WRONLY | File::CREAT, 0o600) { nil }
            File.chmod(0o600, destination)
            write_text_file(destination, content)
          end

          def android_signing_properties
            from_env = ANDROID_SIGNING_KEYS.each_with_object({}) do |(key, variable), out|
              value = ENV[variable].to_s.strip
              out[key] = value unless value.empty?
            end
            unless from_env.empty?
              from_env["storeFile"] = File.expand_path(from_env["storeFile"]) if from_env["storeFile"]
              # These are the values themselves, not Properties text, so they
              # are escaped the way Gradle's Properties#load reads them back.
              from_env.transform_values! { |value| java_properties_escape(value) }
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

            # storeFile is written relative to the project; the client sits
            # deeper. The project's own values are Properties text and are
            # copied as written, but the folder this joins them to is not: its
            # non-ASCII characters ("Développement") are escaped.
            if parsed["storeFile"] && !Pathname.new(parsed["storeFile"]).absolute?
              expanded = File.expand_path(parsed["storeFile"], File.dirname(source))
              parsed["storeFile"] = java_properties_escape_non_ascii(expanded)
            end
            parsed.merge("_source" => source)
          end

          # java.util.Properties#load, which the client's build.gradle.kts reads
          # key.properties with, decodes backslash escapes, ends a value at a
          # line break, skips the blanks a value starts with and reads the file
          # as ISO-8859-1. A value that is not Properties text (a RUFLET_ANDROID_*
          # variable, an expanded path) is escaped so load returns it unchanged.
          # Only what load would misread is escaped, so a value it already read
          # correctly is written byte for byte as before; Properties#store would
          # also escape a leading # or !, tabs and form feeds, which load reads
          # fine.
          def java_properties_escape(value)
            text = java_properties_utf8(value)
            unless text.valid_encoding?
              # Not text in any encoding we can tell: keep its bytes as they were
              # always written, escaping only what breaks the line.
              return text.b.gsub(/[\\\n\r]/n, JAVA_PROPERTIES_ESCAPES).force_encoding(Encoding::UTF_8)
            end

            escaped = text.gsub(/[\\\n\r]/, JAVA_PROPERTIES_ESCAPES)
            escaped = escaped.sub(/\A[ \t\f]/, JAVA_PROPERTIES_LEADING_BLANKS)
            java_properties_escape_non_ascii(escaped)
          end

          # Anything outside ASCII as \uXXXX UTF-16 code units, as
          # Properties#store writes it. Load reads raw UTF-8 bytes as
          # ISO-8859-1, so such a value could never be read back as written.
          def java_properties_escape_non_ascii(value)
            text = java_properties_utf8(value)
            return text unless text.valid_encoding?

            text.gsub(/[^\x00-\x7F]/) do |char|
              char.encode(Encoding::UTF_16BE).unpack("n*").map { |unit| format("\\u%04X", unit) }.join
            end
          end

          # Values reach us tagged with the locale's encoding: transcode them, as
          # writing them did, except under a C/POSIX locale, which tags UTF-8
          # bytes as binary (writing those raised Encoding::UndefinedConversionError).
          def java_properties_utf8(value)
            text = value.to_s
            return text.dup.force_encoding(Encoding::UTF_8) if text.encoding == Encoding::BINARY

            text.encode(Encoding::UTF_8)
          rescue EncodingError
            text.dup.force_encoding(Encoding::UTF_8)
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
