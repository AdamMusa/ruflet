# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class CameraControl < Ruflet::Control
          TYPE = "camera".freeze
          WIRE = "Camera".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :content, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :preview_enabled, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_error, :on_size_change, :on_state_change, :on_stream_image].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end

          %w[
            get_available_cameras get_exposure_offset_step_size get_max_exposure_offset
            get_max_zoom_level get_min_exposure_offset get_min_zoom_level
            unlock_capture_orientation pause_preview resume_preview take_picture
            prepare_for_video_recording start_video_recording pause_video_recording
            resume_video_recording stop_video_recording supports_image_streaming
            start_image_stream stop_image_stream
          ].each do |method_name|
            define_method(method_name) do |timeout: 10, on_result: nil|
              invoke_camera(method_name, timeout: timeout, on_result: on_result)
            end
          end

          # Ruby reserves #initialize for object construction, so the Flet
          # Camera.initialize() operation is exposed as #initialize_camera.
          def initialize_camera(description, resolution_preset, enable_audio: true, fps: nil,
                                video_bitrate: nil, audio_bitrate: nil,
                                image_format_group: nil, timeout: 10, on_result: nil)
            invoke_camera(
              "initialize",
              args: compact_args(
                description: description,
                resolution_preset: resolution_preset,
                enable_audio: enable_audio,
                fps: fps,
                video_bitrate: video_bitrate,
                audio_bitrate: audio_bitrate,
                image_format_group: image_format_group
              ),
              timeout: timeout,
              on_result: on_result
            )
          end

          def lock_capture_orientation(orientation = nil, timeout: 10, on_result: nil)
            invoke_camera(
              "lock_capture_orientation",
              args: { "orientation" => normalize_value(orientation) },
              timeout: timeout,
              on_result: on_result
            )
          end

          {
            set_description: :description,
            set_exposure_mode: :mode,
            set_exposure_offset: :offset,
            set_exposure_point: :point,
            set_flash_mode: :mode,
            set_focus_mode: :mode,
            set_focus_point: :point,
            set_zoom_level: :zoom
          }.each do |method_name, argument_name|
            define_method(method_name) do |value, timeout: 10, on_result: nil|
              invoke_camera(
                method_name.to_s,
                args: { argument_name.to_s => normalize_value(value) },
                timeout: timeout,
                on_result: on_result
              )
            end
          end

          private

          def invoke_camera(method_name, args: nil, timeout:, on_result:)
            runtime_page&.invoke(self, method_name, args: args, timeout: timeout, on_result: on_result)
          end

          def compact_args(values)
            values.each_with_object({}) do |(key, value), result|
              result[key.to_s] = normalize_value(value) unless value.nil?
            end
          end

          def normalize_value(value)
            case value
            when Array
              value.map { |item| normalize_value(item) }
            when Hash
              value.each_with_object({}) { |(key, item), result| result[key.to_s] = normalize_value(item) }
            when Symbol
              value.to_s
            else
              value.respond_to?(:to_h) ? normalize_value(value.to_h) : value
            end
          end
        end
      end
    end
  end
end
