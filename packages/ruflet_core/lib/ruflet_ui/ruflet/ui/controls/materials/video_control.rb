# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class VideoControl < Ruflet::Control
          TYPE = "video".freeze
          WIRE = "Video".freeze

          def initialize(id: nil, alignment: nil, aspect_ratio: nil, autoplay: nil, configuration: nil, data: nil, fill_color: nil, filter_quality: nil, fit: nil, fullscreen: nil, height: nil, key: nil, muted: nil, opacity: nil, pause_upon_entering_background_mode: nil, pitch: nil, playlist: nil, playlist_mode: nil, playback_rate: nil, resume_upon_entering_foreground_mode: nil, rtl: nil, show_controls: nil, shuffle_playlist: nil, subtitle_configuration: nil, title: nil, tooltip: nil, visible: nil, volume: nil, wakelock: nil, width: nil, on_completed: nil, on_complete: nil, on_enter_fullscreen: nil, on_error: nil, on_exit_fullscreen: nil, on_load: nil, on_loaded: nil, on_state_change: nil, on_track_change: nil, on_track_changed: nil)
            props = {}
            props[:alignment] = alignment unless alignment.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:autoplay] = autoplay unless autoplay.nil?
            props[:configuration] = configuration unless configuration.nil?
            props[:data] = data unless data.nil?
            props[:fill_color] = fill_color unless fill_color.nil?
            props[:filter_quality] = filter_quality unless filter_quality.nil?
            props[:fit] = fit unless fit.nil?
            props[:fullscreen] = fullscreen unless fullscreen.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:muted] = muted unless muted.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:pause_upon_entering_background_mode] = pause_upon_entering_background_mode unless pause_upon_entering_background_mode.nil?
            props[:pitch] = pitch unless pitch.nil?
            props[:playlist] = playlist unless playlist.nil?
            props[:playlist_mode] = playlist_mode unless playlist_mode.nil?
            props[:playback_rate] = playback_rate unless playback_rate.nil?
            props[:resume_upon_entering_foreground_mode] = resume_upon_entering_foreground_mode unless resume_upon_entering_foreground_mode.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:show_controls] = show_controls unless show_controls.nil?
            props[:shuffle_playlist] = shuffle_playlist unless shuffle_playlist.nil?
            props[:subtitle_configuration] = subtitle_configuration unless subtitle_configuration.nil?
            props[:title] = title unless title.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:volume] = volume unless volume.nil?
            props[:wakelock] = wakelock unless wakelock.nil?
            props[:width] = width unless width.nil?
            props[:on_completed] = on_completed unless on_completed.nil?
            props[:on_complete] = on_complete unless on_complete.nil?
            props[:on_enter_fullscreen] = on_enter_fullscreen unless on_enter_fullscreen.nil?
            props[:on_error] = on_error unless on_error.nil?
            props[:on_exit_fullscreen] = on_exit_fullscreen unless on_exit_fullscreen.nil?
            props[:on_load] = on_load unless on_load.nil?
            props[:on_loaded] = on_loaded unless on_loaded.nil?
            props[:on_state_change] = on_state_change unless on_state_change.nil?
            props[:on_track_change] = on_track_change unless on_track_change.nil?
            props[:on_track_changed] = on_track_changed unless on_track_changed.nil?
            super(type: TYPE, id: id, **props)
          end

          def get_current_position(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "get_current_position", timeout: timeout, on_result: on_result)
          end

          def get_duration(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "get_duration", timeout: timeout, on_result: on_result)
          end

          def is_completed(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "is_completed", timeout: timeout, on_result: on_result)
          end

          def is_playing(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "is_playing", timeout: timeout, on_result: on_result)
          end

          def jump_to(media_index, timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "jump_to", args: { "media_index" => media_index }, timeout: timeout, on_result: on_result)
          end

          def next(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "next", timeout: timeout, on_result: on_result)
          end

          def pause(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "pause", timeout: timeout, on_result: on_result)
          end

          def play(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "play", timeout: timeout, on_result: on_result)
          end

          def play_or_pause(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "play_or_pause", timeout: timeout, on_result: on_result)
          end

          def playlist_add(media = nil, timeout: 10, on_result: nil, **props)
            item = media || props
            runtime_page&.invoke(self, "playlist_add", args: { "media" => stringify_hash_keys(item) }, timeout: timeout, on_result: on_result)
          end

          def playlist_remove(media_index, timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "playlist_remove", args: { "media_index" => media_index }, timeout: timeout, on_result: on_result)
          end

          def previous(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "previous", timeout: timeout, on_result: on_result)
          end

          def seek(position_milliseconds, timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "seek", args: { "position" => position_milliseconds }, timeout: timeout, on_result: on_result)
          end

          def stop(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "stop", timeout: timeout, on_result: on_result)
          end

          private

          def stringify_hash_keys(value)
            return value.map { |item| stringify_hash_keys(item) } if value.is_a?(Array)
            return value.each_with_object({}) { |(key, child), result| result[key.to_s] = stringify_hash_keys(child) } if value.is_a?(Hash)

            value
          end
        end
      end
    end
  end
end
