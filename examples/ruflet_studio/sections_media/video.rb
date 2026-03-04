# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_video(page, status)
      video = control(
        :video,
        width: 320,
        height: 180,
        aspect_ratio: 16 / 9.0,
        playlist: [
          { "resource" => "https://user-images.githubusercontent.com/28951144/229373720-14d69157-1a56-4a78-a2f4-d7a134d7c3e9.mp4" },
          { "resource" => "https://user-images.githubusercontent.com/28951144/229373718-86ce5e1d-d195-45d5-baa6-ef94041d0b90.mp4" }
        ],
        playlist_mode: "loop",
        autoplay: false,
        volume: 100,
        playback_rate: 1.0,
        on_load: ->(_e) { page.update(status, value: "Video loaded") },
        on_enter_fullscreen: ->(_e) { page.update(status, value: "Video fullscreen") },
        on_exit_fullscreen: ->(_e) { page.update(status, value: "Video exit fullscreen") },
        on_state_change: ->(e) { page.update(status, value: "Video state: #{e.data}") },
        on_error: ->(e) { page.update(status, value: "Video error: #{e.data}") }
      )

      send_video = lambda do |label, method_name, args: nil|
        page.update(status, value: "Video: #{label}")
        page.invoke(video, method_name, args: args)
      end

      column(
        spacing: 8,
        controls: [
          status,
          control(:safe_area, content: column(
            spacing: 12,
            controls: [
              video,
              column(
                spacing: 8,
                controls: [
                  button(text: "Play", on_click: ->(_e) { send_video.call("Play", "play") }),
                  button(text: "Pause", on_click: ->(_e) { send_video.call("Pause", "pause") }),
                  button(text: "Play/Pause", on_click: ->(_e) { send_video.call("Play/Pause", "play_or_pause") }),
                  button(text: "Stop", on_click: ->(_e) { send_video.call("Stop", "stop") }),
                  button(text: "Next", on_click: ->(_e) { send_video.call("Next", "next") }),
                  button(text: "Prev", on_click: ->(_e) { send_video.call("Prev", "previous") })
                ]
              ),
              column(
                spacing: 8,
                controls: [
                  button(text: "Seek 10s", on_click: ->(_e) { send_video.call("Seek 10s", "seek", args: { position: 10_000 }) }),
                  button(text: "Fullscreen", on_click: ->(_e) { page.update(video, fullscreen: true) })
                ]
              ),
              control(
                :slider,
                min: 0,
                max: 100,
                value: 100,
                divisions: 10,
                label: "Volume = {value}%",
                on_change: ->(e) {
                  page.update(video, volume: read_number(e.data, "value") || 100)
                }
              ),
              control(
                :slider,
                min: 1,
                max: 3,
                value: 1,
                divisions: 6,
                label: "Playback rate = {value}x",
                on_change: ->(e) {
                  page.update(video, playback_rate: read_number(e.data, "value") || 1)
                }
              )
            ]
          ))
        ]
      )
    end
  end
end
