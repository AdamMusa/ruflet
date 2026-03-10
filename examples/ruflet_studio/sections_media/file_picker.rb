# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_file_picker(page, status)
      selected_files = text(value: "")
      save_file_path = text(value: "")
      directory_path = text(value: "")
      picker_in_flight = false

      column(
        spacing: 10,
        children: [
          status,
          row(
            children: [
              button(
                content: "Pick files",
                icon: "upload_file",
                on_click: ->(_e) do
                  next if picker_in_flight
                  picker_in_flight = true
                  page.pick_files(
                    allow_multiple: true,
                    with_data: false,
                    timeout: nil,
                    on_result: lambda { |result, error|
                      picker_in_flight = false
                      if error && !error.to_s.empty?
                        page.update(selected_files, value: "File picker error: #{error}")
                        next
                      end
                      files = Array(result)
                      names = files.map { |f| f["name"] || f[:name] }.compact.join(", ")
                      page.update(selected_files, value: names.empty? ? "Cancelled!" : names)
                    }
                  )
                end
              ),
              container(expand: true, content: selected_files)
            ]
          ),
          row(
            children: [
              button(
                content: "Save file",
                icon: "save",
                on_click: ->(_e) do
                  next if picker_in_flight
                  picker_in_flight = true
                  page.save_file(
                    timeout: nil,
                    on_result: lambda { |result, error|
                      picker_in_flight = false
                      if error && !error.to_s.empty?
                        page.update(save_file_path, value: "File picker error: #{error}")
                        next
                      end
                      page.update(save_file_path, value: result.to_s.empty? ? "Cancelled!" : result.to_s)
                    }
                  )
                end
              ),
              container(expand: true, content: save_file_path)
            ]
          ),
          row(
            children: [
              button(
                content: "Open directory",
                icon: "folder_open",
                on_click: ->(_e) do
                  next if picker_in_flight
                  picker_in_flight = true
                  page.get_directory_path(
                    timeout: nil,
                    on_result: lambda { |result, error|
                      picker_in_flight = false
                      if error && !error.to_s.empty?
                        page.update(directory_path, value: "File picker error: #{error}")
                        next
                      end
                      page.update(directory_path, value: result.to_s.empty? ? "Cancelled!" : result.to_s)
                    }
                  )
                end
              ),
              container(expand: true, content: directory_path)
            ]
          )
        ]
      )
    end
  end
end
