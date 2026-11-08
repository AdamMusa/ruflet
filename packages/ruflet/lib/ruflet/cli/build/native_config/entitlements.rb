# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module NativeConfig
        # Writes the macOS Runner's DebugProfile.entitlements and
        # Release.entitlements.
        module Entitlements
          private

          # Removes every boolean entitlement named in `managed` from both
          # files, then enables each of `enabled` at the end of the
          # dictionary. Entitlements outside `managed` are kept.
          def write_macos_entitlements(client_dir, managed:, enabled:)
            %w[DebugProfile.entitlements Release.entitlements].each do |name|
              path = File.join(client_dir, "macos", "Runner", name)
              next unless File.file?(path)

              content = read_text_file(path)
              managed.each do |key|
                content.gsub!(
                  %r{\s*<key>#{Regexp.escape(key)}</key>\s*<(?:true|false)\s*/>}m,
                  ""
                )
              end
              enabled.each do |key|
                pair = "\t<key>#{key}</key>\n\t<true/>\n"
                content.sub!(%r{</dict>\s*</plist>}m, "#{pair}</dict>\n</plist>")
              end
              write_text_file(path, content)
            end
          end
        end
      end
    end
  end
end
