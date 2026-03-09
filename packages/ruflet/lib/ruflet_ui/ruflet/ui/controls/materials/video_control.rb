# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class VideoControl < Ruflet::Control
          TYPE = "video".freeze
          WIRE = "Video".freeze

          def initialize(id: nil, aspect_ratio: nil, autoplay: nil, data: nil, fullscreen: nil, height: nil, key: nil, opacity: nil, playlist: nil, playlist_mode: nil, playback_rate: nil, rtl: nil, tooltip: nil, visible: nil, volume: nil, width: nil, on_enter_fullscreen: nil, on_error: nil, on_exit_fullscreen: nil, on_load: nil, on_state_change: nil)
            props = {}
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:autoplay] = autoplay unless autoplay.nil?
            props[:data] = data unless data.nil?
            props[:fullscreen] = fullscreen unless fullscreen.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:playlist] = playlist unless playlist.nil?
            props[:playlist_mode] = playlist_mode unless playlist_mode.nil?
            props[:playback_rate] = playback_rate unless playback_rate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:volume] = volume unless volume.nil?
            props[:width] = width unless width.nil?
            props[:on_enter_fullscreen] = on_enter_fullscreen unless on_enter_fullscreen.nil?
            props[:on_error] = on_error unless on_error.nil?
            props[:on_exit_fullscreen] = on_exit_fullscreen unless on_exit_fullscreen.nil?
            props[:on_load] = on_load unless on_load.nil?
            props[:on_state_change] = on_state_change unless on_state_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
