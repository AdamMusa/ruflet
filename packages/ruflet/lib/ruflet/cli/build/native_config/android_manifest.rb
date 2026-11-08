# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module NativeConfig
        # Writes android/app/src/main/AndroidManifest.xml.
        module AndroidManifest
          private

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
