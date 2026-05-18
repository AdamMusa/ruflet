# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class AudioControl < Ruflet::Control
          TYPE = "audio".freeze
          WIRE = "Audio".freeze

          def initialize(id: nil, autoplay: nil, balance: nil, data: nil, key: nil, opacity: nil, playback_rate: nil, release_mode: nil, rtl: nil, src: nil, src_base64: nil, tooltip: nil, visible: nil, volume: nil, on_duration_change: nil, on_error: nil, on_loaded: nil, on_position_change: nil, on_seek_complete: nil, on_state_change: nil)
            props = {}
            props[:autoplay] = autoplay unless autoplay.nil?
            props[:balance] = balance unless balance.nil?
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:playback_rate] = playback_rate unless playback_rate.nil?
            props[:release_mode] = release_mode unless release_mode.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:src] = src unless src.nil?
            props[:src_base64] = src_base64 unless src_base64.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:volume] = volume unless volume.nil?
            props[:on_duration_change] = on_duration_change unless on_duration_change.nil?
            props[:on_error] = on_error unless on_error.nil?
            props[:on_loaded] = on_loaded unless on_loaded.nil?
            props[:on_position_change] = on_position_change unless on_position_change.nil?
            props[:on_seek_complete] = on_seek_complete unless on_seek_complete.nil?
            props[:on_state_change] = on_state_change unless on_state_change.nil?
            super(type: TYPE, id: id, **props)
          end

          def get_current_position(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "get_current_position", timeout: timeout, on_result: on_result)
          end

          def get_duration(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "get_duration", timeout: timeout, on_result: on_result)
          end

          def pause(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "pause", timeout: timeout, on_result: on_result)
          end

          def play(position: nil, timeout: 10, on_result: nil)
            args = {}
            args["position"] = position unless position.nil?
            runtime_page&.invoke(self, "play", args: args.empty? ? nil : args, timeout: timeout, on_result: on_result)
          end

          def release(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "release", timeout: timeout, on_result: on_result)
          end

          def resume(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "resume", timeout: timeout, on_result: on_result)
          end

          def seek(position_milliseconds = nil, timeout: 10, on_result: nil)
            args = {}
            args["position"] = position_milliseconds unless position_milliseconds.nil?
            runtime_page&.invoke(self, "seek", args: args.empty? ? nil : args, timeout: timeout, on_result: on_result)
          end
        end
      end
    end
  end
end
