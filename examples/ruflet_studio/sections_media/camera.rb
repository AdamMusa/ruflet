# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_camera(page, status)
      camera = page.service(
        :camera,
        preview_enabled: true,
        expand: true,
        on_error: ->(e) { page.update(status, value: "Camera error: #{e.data}") }
      )

      preview = container(
        visible: false,
        height: 320,
        border_radius: 10,
        bgcolor: "#000000",
        border: { width: 1, color: color_divider(page) },
        content: camera
      )

      column(
        spacing: 10,
        children: [
          status,
          button(
            content: text(value: "Open camera"),
            on_click: ->(_e) do
              page.update(status, value: "Checking available cameras...")
              page.invoke(camera, "get_available_cameras", timeout: 30, on_result: lambda { |result, error|
                if error
                  page.update(status, value: "Camera error: #{error}")
                  next
                end

                cameras = Array(result)
                if cameras.empty?
                  page.update(status, value: "No camera available on this device.")
                  next
                end

                page.update(status, value: "Initializing camera...")
                page.invoke(
                  camera,
                  "initialize",
                  args: { "description" => cameras.first },
                  timeout: 60,
                  on_result: lambda { |_init_result, init_error|
                    if init_error
                      page.update(status, value: "Camera init error: #{init_error}")
                    else
                      page.update(preview, visible: true)
                      page.update(status, value: "Camera ready.")
                    end
                  }
                )
              })
            end
          ),
          text(value: "Tap Open camera to initialize and show preview.", style: { size: 12, color: color_subtle(page) }),
          preview
        ]
      )
    end
  end
end
