# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_storage_paths(page, _status)
      page.service(:storage_paths)
      rows_column = column(spacing: 5, children: [])

      pretty_value = lambda do |value|
        return "nil" if value.nil?
        if value.is_a?(Array)
          return value.empty? ? "[]" : value.join(", ")
        end
        value.to_s
      end

      add_row = lambda do |label, value|
        rows = Array(rows_column.children)
        rows << text(value: "#{label}: #{pretty_value.call(value)}")
        page.update(rows_column, controls: rows)
      end

      fail_row = lambda do |label, error|
        add_row.call(label, "Not supported: #{error}")
      end

      fetches = [
        ["Application cache directory", ->(cb) { page.get_application_cache_directory(timeout: nil, on_result: cb) }],
        ["Application documents directory", ->(cb) { page.get_application_documents_directory(timeout: nil, on_result: cb) }],
        ["Application support directory", ->(cb) { page.get_application_support_directory(timeout: nil, on_result: cb) }],
        ["Downloads directory", ->(cb) { page.get_downloads_directory(timeout: nil, on_result: cb) }],
        ["External cache directories", ->(cb) { page.get_external_cache_directories(timeout: nil, on_result: cb) }],
        ["External storage directories", ->(cb) { page.get_external_storage_directories(timeout: nil, on_result: cb) }],
        ["Library directory", ->(cb) { page.get_library_directory(timeout: nil, on_result: cb) }],
        ["External storage directory", ->(cb) { page.get_external_storage_directory(timeout: nil, on_result: cb) }],
        ["Temporary directory", ->(cb) { page.get_temporary_directory(timeout: nil, on_result: cb) }],
        ["Console log filename", ->(cb) { page.get_console_log_filename(timeout: nil, on_result: cb) }]
      ]

      run_next = nil
      run_next = lambda do |index|
        return if index >= fetches.length

        label, runner = fetches[index]
        runner.call(lambda { |result, error|
          if error && !error.to_s.empty?
            fail_row.call(label, error)
          elsif result.nil? || (result.respond_to?(:empty?) && result.empty?)
            add_row.call(label, "Not supported on this platform")
          else
            add_row.call(label, result)
          end
          run_next.call(index + 1)
        })
      end

      Thread.new do
        sleep(0.15)
        run_next.call(0)
      rescue StandardError => e
        fail_row.call("Storage paths", e.message)
      end

      column(
        spacing: 8,
        children: [
          rows_column
        ]
      )
    end
  end
end
