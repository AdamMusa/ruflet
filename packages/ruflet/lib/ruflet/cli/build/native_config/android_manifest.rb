# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module NativeConfig
        # Writes android/app/src/main/AndroidManifest.xml.
        module AndroidManifest
          private

          # Removes every <uses-permission> named in `managed`, then declares
          # each of `permissions` the manifest does not already declare, right
          # after the <manifest> tag. Permissions outside `managed` are kept.
          def write_android_manifest_permissions(client_dir, managed:, permissions:)
            path = File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
            return unless File.file?(path)

            content = read_text_file(path)
            managed.each do |permission|
              content.gsub!(
                %r{^\s*<uses-permission\b[^>]*android:name="#{Regexp.escape(permission)}"[^>]*/>\s*\n?},
                ""
              )
            end
            permissions.each do |permission|
              next if content.include?(%(android:name="#{permission}"))

              content.sub!(/<manifest\b[^>]*>\s*/, "\\0    <uses-permission android:name=\"#{permission}\"/>\n")
            end
            write_text_file(path, content)
          end

          def upsert_android_metadata(path, name, value)
            content = read_text_file(path)
            escaped_value = xml_escape(value)
            tag = %(        <meta-data android:name="#{name}" android:value="#{escaped_value}" />)
            pattern = %r{\s*<meta-data\s+android:name=["']#{Regexp.escape(name)}["'][^>]*/>}m
            if content.match?(pattern)
              content.sub!(pattern, "\n#{tag}")
            else
              content.sub!(%r{(<application\b[^>]*>)}, "\\1\n#{tag}")
            end
            write_text_file(path, content)
          end

          def set_android_meta_data(manifest, name, value)
            contents = File.read(manifest)
            entry = %(<meta-data android:name="#{name}" android:value="#{value}" />)
            existing = /<meta-data\s+android:name="#{Regexp.escape(name)}"[^>]*\/>/

            contents =
              if contents.match?(existing)
                contents.sub(existing, entry)
              else
                contents.sub(%r{(\n(\s*)</application>)}) { "\n#{$2}    #{entry}#{$1}" }
              end
            File.write(manifest, contents)
          end
        end
      end
    end
  end
end
