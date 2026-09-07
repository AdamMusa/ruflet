# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class VideoControl < Ruflet::Control
          TYPE = "video".freeze
          WIRE = "Video".freeze

          KEYWORDS = [].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
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
