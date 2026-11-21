# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # Text-file IO, escaping and logging shared by every build step.
      module Support
        private

        def extract_option_value!(args, *flags)
          flags.each do |flag|
            index = args.index(flag)
            next unless index

            value = args[index + 1]
            args.slice!(index, 2)
            return value
          end
          nil
        end

        # The value of the first `--flag=value` in args, removed from them.
        def extract_equals_option_value!(args, flag)
          prefix = "#{flag}="
          index = args.index { |arg| arg.start_with?(prefix) }
          return nil unless index

          args.delete_at(index).delete_prefix(prefix)
        end

        # Native project files are UTF-8 and the values written into them are too
        # (the macOS copyright line carries a ©). Reading them with the default
        # external encoding fails outright under a non-UTF-8 locale, so pin it.
        def read_text_file(path)
          File.read(path, encoding: Encoding::UTF_8)
        end

        def write_text_file(path, content)
          File.write(path, content, encoding: Encoding::UTF_8)
        end

        # Dir.glob(File.join(root, pattern)) reads any [ ] { } * ? in root --
        # the project's own path -- as part of the pattern, so under a folder
        # such as "Apps [2026]" it matches nothing. Globbing relative to root
        # keeps the pattern to what the caller wrote. Returns full paths, in
        # the order Dir.glob gives them.
        def glob_under(root, pattern, flags = 0)
          Dir.glob(pattern, flags, base: root).map { |relative| File.join(root, relative) }
        end

        def replace_in_file(path, pattern, replacement)
          return unless File.file?(path)

          content = read_text_file(path)
          updated = content.gsub(pattern) { replacement }
          write_text_file(path, updated) unless updated == content
        end

        def xml_escape(value)
          value.to_s
               .gsub("&", "&amp;")
               .gsub("<", "&lt;")
               .gsub(">", "&gt;")
               .gsub('"', "&quot;")
               .gsub("'", "&apos;")
        end

        def html_escape(value)
          xml_escape(value)
        end

        def xcode_escape(value)
          value.to_s.gsub("\\", "\\\\\\").gsub('"', '\"')
        end

        def windows_string_escape(value)
          value.to_s.gsub('"', '""')
        end

        # One segment of a URI path, percent-encoded as RFC 3986 and Dart's
        # Uri(pathSegments:) do: letters, digits and -._~!$&'()*+,;=:@ stay as
        # they are, and every other byte of the UTF-8 text becomes %XX.
        def uri_path_segment_escape(segment)
          segment.to_s.b.gsub(%r{[^A-Za-z0-9\-._~!$&'()*+,;=:@]}n) { |byte| format("%%%02X", byte.ord) }
                 .force_encoding(Encoding::UTF_8)
        end

        # A POSIX path already starts with "/", so "file://" + path gives the
        # three slashes a file URI needs. A Windows path starts with the drive
        # ("D:/..."), and without the extra slash "D:" is parsed as the URI's
        # host -- which is why this read every bundled package as missing there.
        #
        # Each segment is escaped on its own, so a folder named "Apps [2026]"
        # or "What?" stays part of the path instead of making the URI invalid
        # or starting its query.
        def file_uri_for(path)
          escaped = path.tr("\\", "/").split("/", -1).map { |segment| uri_path_segment_escape(segment) }.join("/")
          escaped.start_with?("/") ? "file://#{escaped}" : "file:///#{escaped}"
        end

        # And back: URI#path keeps that leading slash, so a Windows path returns
        # as "/D:/..." which no file API accepts.
        def path_from_file_uri(uri)
          URI::DEFAULT_PARSER.unescape(uri.path).sub(%r{\A/(?=[A-Za-z]:)}, "")
        end

        def build_log(verbose, message)
          return unless verbose

          puts "[ruflet build] #{message}"
        end

        def build_note(message)
          puts "[ruflet build] #{message}"
        end
      end
    end
  end
end
