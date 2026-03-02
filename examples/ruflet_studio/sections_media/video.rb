# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_video(page, status)
      video = page.control(
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
        on_exit_fullscreen: ->(_e) { page.update(status, value: "Video exit fullscreen") }
      )

      page.column(
        spacing: 8,
        controls: [
          status,
          page.control(:safe_area, content: page.column(
            spacing: 12,
            controls: [
              video,
              page.column(
                spacing: 8,
                controls: [
                  page.button(text: "Play", on_click: ->(_e) { page.invoke(video, "play") }),
                  page.button(text: "Pause", on_click: ->(_e) { page.invoke(video, "pause") }),
                  page.button(text: "Play/Pause", on_click: ->(_e) { page.invoke(video, "play_or_pause") }),
                  page.button(text: "Stop", on_click: ->(_e) { page.invoke(video, "stop") }),
                  page.button(text: "Next", on_click: ->(_e) { page.invoke(video, "next") }),
                  page.button(text: "Prev", on_click: ->(_e) { page.invoke(video, "previous") })
                ]
              ),
              page.column(
                spacing: 8,
                controls: [
                  page.button(text: "Seek 10s", on_click: ->(_e) { page.invoke(video, "seek", args: { position: 10_000 }) }),
                  page.button(text: "Fullscreen", on_click: ->(_e) { page.update(video, fullscreen: true) })
                ]
              ),
              page.control(
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
              page.control(
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
