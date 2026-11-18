# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module NativeConfig
        # Writes the client's pubspec.yaml.
        module Pubspec
          private

          def write_pubspec_yaml(path, data)
            content = YAML.dump(data)
            content = content.sub(/\A---\n/, "")

            content = indent_pubspec_sequences(content)

            write_text_file(path, content)
          end

          def indent_pubspec_sequences(content)
            current_key_indent = nil
            content.lines.map do |line|
              if (match = line.match(/\A(\s*)[^#\s][^:]*:\s*(?:#.*)?\n?\z/))
                current_key_indent = match[1].length
              elsif (match = line.match(/\A(\s*)-\s/)) && current_key_indent && match[1].length <= current_key_indent
                line = (" " * (current_key_indent + 2)) + line.lstrip
              end

              line
            end.join
          end

          # update_pubspec_value only rewrites blocks that already exist. Create the
          # block first so a template without it still receives the configured values.
          def ensure_pubspec_block(path, block)
            return unless File.file?(path)

            content = read_text_file(path)
            return if content.lines.any? { |line| line.start_with?("#{block}:") }

            content += "\n" unless content.empty? || content.end_with?("\n")
            write_text_file(path, "#{content}#{block}:\n")
          end

          # Writes `block: -> section: -> key: value`, creating the block and the
          # nested section when they are missing (for example flutter_native_splash's
          # android_12 section).
          def update_pubspec_nested_value(path, block, section, key, value)
            return unless File.file?(path)

            ensure_pubspec_block(path, block)
            lines = read_text_file(path).split("\n", -1)
            block_start = lines.index { |line| line.start_with?("#{block}:") }
            return unless block_start

            block_end = block_start + 1
            block_end += 1 while block_end < lines.length && (lines[block_end].strip.empty? || lines[block_end].start_with?(" ", "\t"))
            block_end -= 1 while block_end > block_start + 1 && lines[block_end - 1].strip.empty?

            section_index = (block_start + 1...block_end).find do |index|
              lines[index] =~ /\A\s{2}#{Regexp.escape(section)}:\s*(#.*)?\z/
            end

            if section_index.nil?
              lines.insert(block_end, "  #{section}:", "    #{key}: #{value}")
            else
              section_end = section_index + 1
              section_end += 1 while section_end < block_end && lines[section_end] =~ /\A\s{3,}\S/
              existing = (section_index + 1...section_end).find { |index| lines[index].strip.start_with?("#{key}:") }
              if existing
                lines[existing] = "#{lines[existing][/\A\s*/]}#{key}: #{value}"
              else
                lines.insert(section_end, "    #{key}: #{value}")
              end
            end

            write_text_file(path, indent_pubspec_sequences(lines.join("\n")))
          end

          def update_pubspec_value(path, block, key, value, multiple: false)
            lines = read_text_file(path).split("\n", -1)
            out = []
            in_block = false
            replaced = false
            block_indent = nil
            lines.each do |line|
              if line.start_with?("#{block}:")
                in_block = true
                block_indent = line[/^\s*/] + "  "
                out << line
                next
              end

              if in_block
                if line =~ /^\S/ && !line.start_with?("#{block}:")
                  unless replaced
                    out << "#{block_indent}#{key}: #{value}"
                    replaced = true
                  end
                  in_block = false
                else
                  if line.strip.start_with?("#{key}:")
                    indent = line[/^\s*/]
                    out << "#{indent}#{key}: #{value}"
                    replaced = true
                    next
                  end
                end
              end

              out << line
            end
            if in_block && !replaced
              out << "#{block_indent}#{key}: #{value}"
            end
            write_text_file(path, indent_pubspec_sequences(out.join("\n")))
          end
        end
      end
    end
  end
end
