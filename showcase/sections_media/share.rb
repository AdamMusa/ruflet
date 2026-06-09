# frozen_string_literal: true

require "tmpdir"
require "fileutils"

module Showcase
  module SectionsMedia
    def build_share(page, _status)
      page.share

      status_text = text(value: "")
      raw_text = text(value: "")
      share_in_flight = false

      update_result = lambda do |result, error|
        share_in_flight = false
        if error && !error.to_s.empty?
          page.update(status_text, value: "Share error: #{error}")
          page.update(raw_text, value: "")
          next
        end

        payload = result.is_a?(Hash) ? result : {}
        state = payload["status"] || payload[:status]
        raw = payload["raw"] || payload[:raw]
        state_value = state.to_s.empty? ? "UNKNOWN" : state.to_s.upcase
        raw_value = raw.to_s.empty? ? "(empty)" : raw.to_s
        page.update(status_text, value: "Share status: ShareResultStatus.#{state_value}")
        page.update(raw_text, value: "Raw: #{raw_value}")
      end

      share_sample_file_from_bytes = lambda do |text_value|
        page.share_files(
          [
            {
              "data" => "Sample content from file path\n".b,
              "mime_type" => "text/plain",
              "name" => "sample_from_path.txt"
            }
          ],
          text: text_value,
          download_fallback_enabled: true,
          mail_to_fallback_enabled: true,
          timeout: 30,
          on_result: update_result
        )
      end

      share_text_btn = button(
        content: "Share text",
        on_click: ->(_e) do
          next if share_in_flight

          share_in_flight = true
          page.update(status_text, value: "Opening share sheet...")
          page.update(raw_text, value: "")
          page.share_text(
            "Hello from Ruflet!",
            title: "Share greeting",
            subject: "Greeting",
            download_fallback_enabled: true,
            mail_to_fallback_enabled: true,
            timeout: 30,
            on_result: update_result
          )
        end
      )

      share_link_btn = button(
        content: "Share link",
        on_click: ->(_e) do
          next if share_in_flight

          share_in_flight = true
          page.update(status_text, value: "Opening share sheet...")
          page.update(raw_text, value: "")
          page.share_uri(
            "https://ruflet.dev",
            timeout: 30,
            on_result: update_result
          )
        end
      )

      share_bytes_btn = button(
        content: "Share file from bytes",
        on_click: ->(_e) do
          next if share_in_flight

          share_in_flight = true
          page.update(status_text, value: "Opening share sheet...")
          page.update(raw_text, value: "")
          page.share_files(
            [
              {
                "data" => "Sample content from memory".b,
                "mime_type" => "text/plain",
                "name" => "sample.txt"
              }
            ],
            text: "Sharing a file from memory",
            download_fallback_enabled: true,
            mail_to_fallback_enabled: true,
            timeout: 30,
            on_result: update_result
          )
        end
      )

      share_path_btn = button(
        content: "Share file from path",
        on_click: ->(_e) do
          next if share_in_flight

          share_in_flight = true
          page.update(status_text, value: "Preparing file for share...")
          page.update(raw_text, value: "")

          sample_content = "Sample content from file path\n"
          begin
            base_dir = File.join(Dir.tmpdir, "ruflet_share_example")
            FileUtils.mkdir_p(base_dir)
            sample_path = File.join(base_dir, "sample_from_path.txt")
            File.write(sample_path, sample_content)
          rescue StandardError => e
            page.update(status_text, value: "Path share fallback: #{e.class}: #{e.message}")
            share_sample_file_from_bytes.call("Sharing a file from path fallback")
            next
          end

          page.update(status_text, value: "Opening share sheet...")
          page.share_files(
            [sample_path],
            text: "Sharing a file from path",
            download_fallback_enabled: true,
            mail_to_fallback_enabled: true,
            timeout: 30,
            on_result: update_result
          )
        end
      )

      control(
        :safe_area,
        content: column(
          children: [
            row(
              wrap: true,
              children: [
                share_text_btn,
                share_link_btn,
                share_bytes_btn,
                share_path_btn
              ]
            ),
            status_text,
            raw_text
          ]
        )
      )
    end
  end
end
