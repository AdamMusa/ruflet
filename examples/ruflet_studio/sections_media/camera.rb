# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_camera(page, status)
      camera = page.service(
        :camera,
        preview_enabled: true,
        on_error: ->(e) { page.update(status, value: "Camera error: #{e.data}") }
      )
      camera_busy = false
      open_button = nil

      preview = container(
        visible: false,
        height: 320,
        border_radius: 10,
        bgcolor: color_panel(page),
        border: { width: 1, color: color_divider(page) },
        content: camera
      )

      open_button = button(
        content: text(value: "Open camera"),
        on_click: ->(_e) do
          next if camera_busy
          camera_busy = true
          page.update(open_button, disabled: true)
          page.update(status, value: "Checking available cameras...")
          page.invoke(
            camera,
            "get_available_cameras",
            timeout: 45,
            on_result: lambda { |result, error|
              if error && !error.to_s.empty?
                camera_busy = false
                page.update(open_button, disabled: false)
                page.update(status, value: "Camera error: #{error}")
                next
              end

              cameras = Array(result)
              if cameras.empty?
                camera_busy = false
                page.update(open_button, disabled: false)
                page.update(status, value: "No camera available on this device.")
                next
              end

              page.update(status, value: "Initializing camera...")
              page.invoke(
                camera,
                "initialize",
                args: {
                  "description" => cameras.first,
                  "resolution_preset" => "medium",
                  "enable_audio" => false,
                  "image_format_group" => "jpeg"
                },
                timeout: 180,
                on_result: lambda { |_init_result, init_error|
                  camera_busy = false
                  page.update(open_button, disabled: false)
                  if init_error && !init_error.to_s.empty?
                    page.update(status, value: "Camera error: #{init_error}")
                  else
                    page.update(preview, visible: true)
                    page.update(status, value: "Camera initialized.")
                  end
                }
              )
            }
          )
        end
      )

      column(
        spacing: 10,
        children: [
          status,
          open_button,
          text(value: "Tap Open camera to initialize and show preview.", style: { size: 12 }),
          preview
        ]
      )
    end
  end
end
