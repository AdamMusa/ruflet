# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_camera(page, status)
      return mobile_only_notice(page, "Camera") unless mobile_platform?(page)

      camera = page.camera(
        preview_enabled: true,
        on_error: ->(e) { page.update(status, value: "Camera error: #{e.data}") }
      )
      camera_busy = false
      open_button = nil
      take_picture_button = nil
      initialized = false
      last_picture = text(value: "")

      preview = container(
        height: 1,
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
          Thread.new do
            sleep(2)
            if camera_busy
              page.update(status, value: "Still waiting for the platform camera list...")
            end
          end
          page.invoke(
            camera,
            "get_available_cameras",
            timeout: 5,
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
                    initialized = true
                    page.update(preview, height: 320)
                    page.update(take_picture_button, disabled: false)
                    page.update(status, value: "Camera initialized.")
                  end
                }
              )
            }
          )
        end
      )

      take_picture_button = button(
        content: text(value: "Take picture"),
        disabled: true,
        on_click: ->(_e) do
          unless initialized
            page.update(status, value: "Initialize camera first.")
            next
          end

          page.update(status, value: "Taking picture...")
          page.invoke(
            camera,
            "take_picture",
            timeout: 45,
            on_result: lambda { |result, error|
              if error && !error.to_s.empty?
                page.update(status, value: "Camera error: #{error}")
                next
              end

              bytes = result.respond_to?(:bytesize) ? result.bytesize : Array(result).length
              page.update(last_picture, value: "Last picture: #{bytes} bytes")
              page.update(status, value: "Picture captured.")
            }
          )
        end
      )

      column(
        spacing: 10,
        children: [
          status,
          row(spacing: 8, wrap: true, children: [open_button, take_picture_button]),
          text(value: "Tap Open camera to initialize and show preview.", style: { size: 12 }),
          last_picture,
          preview
        ]
      )
    end
  end
end
