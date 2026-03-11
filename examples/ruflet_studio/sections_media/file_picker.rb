# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_file_picker(page, status)
      file_picker = page.service(:filepicker)
      picker_busy = false
      open_button = nil

      open_button = button(
        content: text(value: "Open file picker"),
        on_click: ->(_e) do
          next if picker_busy
          picker_busy = true
          page.update(open_button, disabled: true)
          page.update(status, value: "Opening file picker...")
          page.invoke(
            file_picker,
            "pick_files",
            args: { "allow_multiple" => false, "with_data" => false },
            timeout: 600,
            on_result: lambda { |result, error|
              picker_busy = false
              page.update(open_button, disabled: false)

              if error && !error.to_s.empty?
                page.update(status, value: "File picker error: #{error}")
                next
              end

              files = Array(result)
              if files.empty?
                page.update(status, value: "No file selected.")
              else
                first = files.first || {}
                name = first["name"] || first[:name] || "unknown"
                path = first["path"] || first[:path] || "no-path"
                page.update(status, value: "Selected: #{name} (#{path})")
              end
            }
          )
        end
      )

      column(
        spacing: 10,
        children: [
          status,
          open_button
        ]
      )
    end
  end
end
