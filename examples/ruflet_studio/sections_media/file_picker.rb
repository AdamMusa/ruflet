# frozen_string_literal: true

require "json"

module RufletStudio
  module SectionsMedia
    def build_file_picker(page, status)
      file_picker = page.service(:file_picker)

      column(
        spacing: 10,
        children: [
          status,
          button(
            text: "Open file picker",
            on_click: ->(_e) do
              page.update(status, value: "Opening file picker...")
              page.invoke(
                file_picker,
                "pick_files",
                args: { "allow_multiple" => false, "with_data" => false },
                timeout: 600,
                on_result: lambda { |result, error|
                  if error
                    page.update(status, value: "File picker error: #{error}")
                    next
                  end

                  files = Array(result)
                  if files.empty?
                    page.update(status, value: "No file selected.")
                    next
                  end

                  first = files.first || {}
                  if first.is_a?(String)
                    begin
                      first = JSON.parse(first)
                    rescue StandardError
                      first = { "name" => first, "path" => nil }
                    end
                  end

                  name = first["name"] || first[:name] || "unknown"
                  path = first["path"] || first[:path] || "no-path"
                  page.update(status, value: "Selected: #{name} (#{path})")
                }
              )
            end
          )
        ]
      )
    end
  end
end
