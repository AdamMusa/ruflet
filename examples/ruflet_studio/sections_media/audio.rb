# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_audio(page, status)
      duration_ms = 0.0
      position_ms = 0.0

      progress = page.control(:progress_bar, value: 0.0)

      audio = page.instance_variable_get(:@audio_service)
      unless audio
        audio = page.control(
          :audio,
          src: "https://github.com/flet-dev/media/raw/refs/heads/main/sounds/sweet-life-luxury-chill-438146.mp3",
          autoplay: false,
          volume: 1.0,
          balance: 0.0,
          release_mode: "stop",
          on_loaded: ->(_e) {
            page.update(status, value: "Audio loaded")
            page.invoke(audio, "get_duration")
          },
          on_duration_change: ->(e) {
            payload = e.data.is_a?(Hash) ? e.data : {}
            duration_ms = payload["duration"].to_f
            duration_ms = duration_ms.positive? ? duration_ms : payload["duration"].to_f
            if duration_ms.positive?
              page.update(play_btn, disabled: false)
              page.update(pause_btn, disabled: false)
              page.update(resume_btn, disabled: false)
              page.update(release_btn, disabled: false)
            end
            page.update(status, value: "Duration: #{duration_ms.to_i}ms")
          },
          on_position_change: ->(e) {
            payload = e.data.is_a?(Hash) ? e.data : {}
            position_ms = payload["position"].to_f
            position_ms = position_ms.positive? ? position_ms : payload["position"].to_f
            if duration_ms.positive?
              page.update(progress, value: (position_ms / duration_ms).clamp(0.0, 1.0))
            end
            page.update(status, value: "Position: #{position_ms.to_i}ms")
          },
          on_state_change: ->(e) { page.update(status, value: "State: #{e.data}") },
          on_seek_complete: ->(_e) { page.update(status, value: "Seek complete") },
          on_error: ->(e) { page.update(status, value: "Audio error: #{e.data}") }
        )
        page.instance_variable_set(:@audio_service, audio)
      end

      page.add_service(audio) unless page.services.include?(audio)

      send_audio = lambda do |label, method_name, args: nil|
        page.update(status, value: "Audio: #{label}")
        page.invoke(audio, method_name, args: args)
      end

      play_btn = page.button(text: "Play", on_click: ->(_e) { send_audio.call("Play", "play") })
      pause_btn = page.button(text: "Pause", on_click: ->(_e) { send_audio.call("Pause", "pause") })
      resume_btn = page.button(text: "Resume", on_click: ->(_e) { send_audio.call("Resume", "resume") })
      release_btn = page.button(text: "Release", on_click: ->(_e) { send_audio.call("Release", "release") })

      adjust_volume = lambda do |delta|
        next_volume = (audio.props["volume"].to_f + delta).clamp(0.0, 1.0)
        page.update(audio, volume: next_volume)
        page.update(status, value: "Volume: #{next_volume.round(2)}")
      end

      adjust_balance = lambda do |delta|
        next_balance = (audio.props["balance"].to_f + delta).clamp(-1.0, 1.0)
        page.update(audio, balance: next_balance)
        page.update(status, value: "Balance: #{next_balance.round(2)}")
      end

      page.column(
        spacing: 8,
        controls: [
          status,
          progress,
          page.column(
            spacing: 8,
            controls: [
              play_btn,
              pause_btn,
              resume_btn,
              release_btn
            ]
          ),
          page.column(
            spacing: 8,
            controls: [
              page.button(text: "Seek 2s", on_click: ->(_e) { send_audio.call("Seek 2s", "seek", args: { position: 2000 }) }),
              page.button(text: "Get duration", on_click: ->(_e) { send_audio.call("Get duration", "get_duration") }),
              page.button(text: "Get position", on_click: ->(_e) { send_audio.call("Get position", "get_current_position") })
            ]
          ),
          page.column(
            spacing: 8,
            controls: [
              page.button(text: "Volume -", on_click: ->(_e) { adjust_volume.call(-0.1) }),
              page.button(text: "Volume +", on_click: ->(_e) { adjust_volume.call(0.1) })
            ]
          ),
          page.column(
            spacing: 8,
            controls: [
              page.button(text: "Balance L", on_click: ->(_e) { adjust_balance.call(-0.1) }),
              page.button(text: "Balance R", on_click: ->(_e) { adjust_balance.call(0.1) })
            ]
          ),
        ]
      )
    end
  end
end
