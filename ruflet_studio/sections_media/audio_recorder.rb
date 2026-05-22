# frozen_string_literal: true

require "fileutils"

module RufletStudio
  module SectionsMedia
    def build_audio_recorder(page, status)
      recorder = page.audio_recorder(key: "studio_audio_recorder")
      recording_path = nil

      column(
        spacing: 8,
        children: [
          status,
          row(
            spacing: 8,
            wrap: true,
            children: [
              text_button(content: text(value: "Permission"), on_click: ->(_e) {
                recorder.has_permission(on_result: ->(result, error) {
                  page.update(status, value: error ? "Recorder permission error: #{error}" : "Recorder microphone permission: #{result.inspect}")
                })
              }),
              text_button(content: text(value: "Input devices"), on_click: ->(_e) {
                recorder.get_input_devices(on_result: ->(result, error) {
                  page.update(status, value: error ? "Devices error: #{error}" : "Devices: #{result.inspect}")
                })
              }),
              text_button(content: text(value: "Start"), on_click: ->(_e) {
                page.update(status, value: "Preparing recording path...")
                page.get_application_documents_directory(on_result: ->(documents_dir, path_error) {
                  if path_error || documents_dir.to_s.empty?
                    page.update(status, value: "Recording path error: #{path_error || "documents directory unavailable"}")
                    next
                  end

                  recording_path = File.join(documents_dir.to_s, "ruflet_studio_recording.wav")
                  next unless prepare_recorder_output_path(page, recording_path, status)

                  recorder.has_permission(on_result: ->(allowed, recorder_error) {
                    if recorder_error
                      page.update(status, value: "Recorder permission error: #{recorder_error}")
                    elsif !allowed
                      page.update(status, value: "Recorder microphone permission was not granted.")
                    else
                      page.update(status, value: "Recording to #{recording_path}")
                      recorder.start_recording(output_path: recording_path, configuration: { encoder: "wav" }, on_result: ->(result, error) {
                        page.update(status, value: error ? "Start error: #{error}" : "Recording started: #{result.inspect}")
                      })
                    end
                  })
                })
              }),
              text_button(content: text(value: "Stop"), on_click: ->(_e) {
                recorder.stop_recording(on_result: ->(result, error) {
                  page.update(status, value: error ? "Stop error: #{error}" : "Recording saved: #{result.inspect || recording_path || "unknown path"}")
                })
              }),
              text_button(content: text(value: "Cancel"), on_click: ->(_e) {
                recorder.cancel_recording(on_result: ->(result, error) {
                  page.update(status, value: error ? "Cancel error: #{error}" : "Recording cancelled: #{result.inspect}")
                })
              })
            ]
          )
        ]
      )
    end

    def prepare_recorder_output_path(page, recording_path, status)
      return true unless %w[macos linux windows].include?(client_platform(page))

      FileUtils.mkdir_p(File.dirname(recording_path))
      FileUtils.touch(recording_path)
      true
    rescue StandardError => e
      page.update(status, value: "Recording file prepare error: #{e.class}: #{e.message}")
      false
    end
  end
end
