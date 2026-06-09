# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module Showcase
  module SectionsMedia
    def build_storage_paths(page, _status)
      page.storage_paths

      status_text = text(value: "Loading temporary path...")
      path_text = text(value: "", selectable: true)
      local_text = text(value: "", selectable: true)

      write_local_sample = lambda do
        local_dir = File.join(Dir.tmpdir, "ruflet_storage_paths_example")
        FileUtils.mkdir_p(local_dir)
        local_path = File.join(local_dir, "sample.txt")
        File.write(local_path, "Hello from Showcase storage paths\n")
        local_path
      end

      page.get_temporary_directory(
        timeout: 10,
        on_result: lambda { |result, error|
          if error && !error.to_s.empty?
            page.update(status_text, value: "Storage paths error: #{error}")
            next
          end

          temporary_directory = result.to_s
          if temporary_directory.empty?
            page.update(status_text, value: "Temporary directory is not available on this platform.")
            next
          end

          page.update(status_text, value: "Temporary directory")
          page.update(path_text, value: File.join(temporary_directory, "sample.txt"))

          begin
            page.update(local_text, value: "Local Ruby sample: #{write_local_sample.call}")
          rescue StandardError => e
            page.update(local_text, value: "Local Ruby sample error: #{e.class}: #{e.message}")
          end
        }
      )

      refresh_btn = button(
        content: "Refresh",
        on_click: ->(_e) do
          page.update(status_text, value: "Loading temporary path...")
          page.update(path_text, value: "")
          page.get_temporary_directory(
            timeout: 10,
            on_result: lambda { |result, error|
              if error && !error.to_s.empty?
                page.update(status_text, value: "Storage paths error: #{error}")
                next
              end

              temporary_directory = result.to_s
              page.update(status_text, value: temporary_directory.empty? ? "Temporary directory is not available." : "Temporary directory")
              page.update(path_text, value: temporary_directory.empty? ? "" : File.join(temporary_directory, "sample.txt"))
            }
          )
        end
      )

      column(
        spacing: 8,
        children: [
          status_text,
          path_text,
          local_text,
          refresh_btn
        ]
      )
    end
  end
end
