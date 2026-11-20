# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module NativeConfig
        # Writes the iOS and macOS Runner/Info.plist.
        module ApplePlist
          private

          def replace_plist_value(path, key, value)
            return unless File.file?(path)

            content = read_text_file(path)
            pattern = %r{(<key>#{Regexp.escape(key)}</key>\s*<string>)(.*?)(</string>)}m
            updated = content.gsub(pattern) do
              "#{Regexp.last_match(1)}#{xml_escape(value)}#{Regexp.last_match(3)}"
            end
            write_text_file(path, updated) unless updated == content
          end

          def apply_apple_service_usage_descriptions(path, entries, usage_keys, managed_keys)
            return unless File.file?(path)

            content = read_text_file(path)
            managed_keys.each do |key|
              content.gsub!(
                %r{\s*<key>#{Regexp.escape(key)}</key>\s*<string>.*?</string>}m,
                ""
              )
            end
            entries.each do |entry|
              description = entry[:description]
              description = "This app uses #{entry[:name]} access for its Ruflet features." if description.empty?
              escaped_description = xml_escape(description)
              Array(usage_keys[entry[:name]]).each do |key|
                pair = "\t<key>#{key}</key>\n\t<string>#{escaped_description}</string>\n"

                if content.match?(%r{<key>#{Regexp.escape(key)}</key>})
                  content.sub!(%r{<key>#{Regexp.escape(key)}</key>\s*<string>.*?</string>}m, "<key>#{key}</key>\n\t<string>#{escaped_description}</string>")
                else
                  content.sub!(%r{</dict>\s*</plist>}m, "#{pair}</dict>\n</plist>")
                end
              end
            end
            write_text_file(path, content)
          end

          def apple_info_plist_paths(client_dir)
            [
              File.join(client_dir, "ios", "Runner", "Info.plist"),
              File.join(client_dir, "macos", "Runner", "Info.plist")
            ].select { |path| File.file?(path) }
          end

          def remove_plist_value(path, key)
            content = read_text_file(path)
            content.gsub!(
              %r{\s*<key>#{Regexp.escape(key)}</key>\s*(?:<string>.*?</string>|<(?:true|false)\s*/>)}m,
              ""
            )
            write_text_file(path, content)
          end

          def remove_plist_dictionary_boolean(path, dictionary_key, key)
            content = read_text_file(path)
            dictionary = content.match(
              %r{<key>#{Regexp.escape(dictionary_key)}</key>\s*<dict>}m)
            return unless dictionary

            opening = content.index("<dict>", dictionary.begin(0))
            return unless opening

            depth = 0
            closing = nil
            content.to_enum(:scan, %r{</?dict>}).each do
              token = Regexp.last_match
              next if token.begin(0) < opening

              depth += token[0] == "<dict>" ? 1 : -1
              if depth.zero?
                closing = token
                break
              end
            end
            return unless closing

            body_start = opening + "<dict>".length
            body = content[body_start...closing.begin(0)]
            updated_body = body.gsub(
              %r{\s*<key>#{Regexp.escape(key)}</key>\s*<(?:true|false)\s*/>}m,
              ""
            )
            return if updated_body == body

            if updated_body.strip.empty?
              pair_start = dictionary.begin(0)
              line_start = content.rindex("\n", pair_start - 1)
              if line_start && content[(line_start + 1)...pair_start].strip.empty?
                pair_start = line_start + 1
              end
              content[pair_start...closing.end(0)] = ""
            else
              content[body_start...closing.begin(0)] = updated_body
            end
            write_text_file(path, content)
          end

          def upsert_plist_string(path, key, value)
            content = read_text_file(path)
            pair = "\t<key>#{key}</key>\n\t<string>#{xml_escape(value)}</string>"
            pattern = %r{<key>#{Regexp.escape(key)}</key>\s*<string>.*?</string>}m
            if content.match?(pattern)
              content.sub!(pattern, pair.strip)
            else
              content.sub!(%r{</dict>\s*</plist>}m, "#{pair}\n</dict>\n</plist>")
            end
            write_text_file(path, content)
          end

          def upsert_plist_boolean(path, key, value)
            content = read_text_file(path)
            pair = "\t<key>#{key}</key>\n\t<#{value ? 'true' : 'false'}/>"
            pattern = %r{<key>#{Regexp.escape(key)}</key>\s*<(?:true|false)\s*/>}m
            if content.match?(pattern)
              content.sub!(pattern, pair.strip)
            else
              content.sub!(%r{</dict>\s*</plist>}m, "#{pair}\n</dict>\n</plist>")
            end
            write_text_file(path, content)
          end

          def upsert_plist_dictionary_boolean(path, dictionary_key, key, value)
            remove_plist_dictionary_boolean(path, dictionary_key, key)
            content = read_text_file(path)
            entry = "<key>#{key}</key>\n\t\t<#{value ? 'true' : 'false'}/>"
            opening = %r{(<key>#{Regexp.escape(dictionary_key)}</key>\s*<dict>)}m
            if content.match?(opening)
              content.sub!(opening) { "#{Regexp.last_match(1)}\n\t\t#{entry}" }
            else
              pair = "\t<key>#{dictionary_key}</key>\n\t<dict>\n\t\t#{entry}\n\t</dict>\n"
              content.sub!(%r{</dict>\s*</plist>}m, "#{pair}</dict>\n</plist>")
            end
            write_text_file(path, content)
          end

          def set_plist_value(plist, key, type, value)
            # Delete first: PlistBuddy's Add fails on an existing key, and a rebuild
            # after renaming the project would otherwise keep the stale name.
            system("/usr/libexec/PlistBuddy", "-c", "Delete :#{key}", plist,
                   out: File::NULL, err: File::NULL)
            system("/usr/libexec/PlistBuddy", "-c", "Add :#{key} #{type} #{value}",
                   plist, out: File::NULL, err: File::NULL)
          end
        end
      end
    end
  end
end
