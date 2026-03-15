# frozen_string_literal: true

require "tmpdir"
require "fileutils"

module RufletStudio
  module SectionsMedia
    def build_clipboard(page, _status)
      state_text = text(value: "")
      files_column = column(horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER, spacing: 0, children: [])

      temp_dir = File.join(Dir.tmpdir, "ruflet_clipboard_files_example")
      FileUtils.mkdir_p(temp_dir)
      sample_files = [
        File.join(temp_dir, "sample_1.txt"),
        File.join(temp_dir, "sample_2.txt")
      ]
      File.write(sample_files[0], "Clipboard sample file 1\n")
      File.write(sample_files[1], "Clipboard sample file 2\n")

      set_files_btn = button(
        content: "Set example files to clipboard",
        on_click: ->(_e) do
          page.set_clipboard_files(
            sample_files,
            on_result: lambda { |result, error|
              if error && !error.to_s.empty?
                page.update(state_text, value: "Clipboard error: #{error}")
                next
              end
              page.update(files_column, controls: [])
              page.update(state_text, value: "Set #{sample_files.length} file references to clipboard (result: #{result}).")
            }
          )
        end
      )

      get_files_btn = button(
        content: "Get files from clipboard",
        on_click: ->(_e) do
          page.get_clipboard_files(
            on_result: lambda { |result, error|
              if error && !error.to_s.empty?
                page.update(state_text, value: "Clipboard error: #{error}")
                page.update(files_column, controls: [])
                next
              end

              paths = Array(result).map(&:to_s).reject(&:empty?)
              rows = paths.map do |path|
                row(
                  alignment: Ruflet::MainAxisAlignment::CENTER,
                  children: [text(value: path, selectable: true)]
                )
              end

              page.update(state_text, value: "Read #{paths.length} file reference(s) from clipboard.")
              page.update(files_column, controls: rows)
            }
          )
        end
      )

      get_image_btn = button(
        content: "Get image from clipboard",
        on_click: ->(_e) do
          page.get_clipboard_image(
            on_result: lambda { |result, error|
              if error && !error.to_s.empty?
                page.update(state_text, value: "Clipboard image error: #{error}")
                next
              end
              if result.nil? || result.to_s.empty?
                page.update(state_text, value: "No image in clipboard.")
              else
                page.update(state_text, value: "Clipboard image available (#{result.to_s.bytesize} bytes payload).")
              end
            }
          )
        end
      )

      control(
        :safe_area,
        content: column(
          horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
          children: [
            set_files_btn,
            get_files_btn,
            get_image_btn,
            state_text,
            files_column
          ]
        )
      )
    end
  end
end
