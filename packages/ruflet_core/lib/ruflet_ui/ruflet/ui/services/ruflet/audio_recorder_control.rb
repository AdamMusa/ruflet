# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class AudioRecorderControl < Ruflet::Control
          TYPE = "audiorecorder".freeze
          WIRE = "AudioRecorder".freeze
          KEYWORDS = [:configuration, :data, :key, :on_state_change, :on_stream, :on_upload].freeze

          def initialize(id: nil, configuration: nil, data: nil, key: nil, on_state_change: nil, on_stream: nil, on_upload: nil)
            configuration ||= {}
            props = {}
            props[:configuration] = configuration
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:on_state_change] = on_state_change unless on_state_change.nil?
            props[:on_stream] = on_stream unless on_stream.nil?
            props[:on_upload] = on_upload unless on_upload.nil?
            super(type: TYPE, id: id, **props)
          end

          %w[cancel_recording get_input_devices has_permission is_paused is_recording pause_recording resume_recording stop_recording].each do |method_name|
            define_method(method_name) do |timeout: 10, on_result: nil|
              invoke_service(method_name, timeout: timeout, on_result: on_result)
            end
          end

          def is_supported_encoder(encoder, timeout: 10, on_result: nil)
            invoke_service("is_supported_encoder", args: { "encoder" => encoder }, timeout: timeout, on_result: on_result)
          end

          def start_recording(output_path: nil, configuration: nil, upload: nil, timeout: 10, on_result: nil)
            configuration = props["configuration"] if configuration.nil?
            invoke_service(
              "start_recording",
              args: compact_args("output_path" => output_path, "configuration" => configuration, "upload" => upload),
              timeout: timeout,
              on_result: on_result
            )
          end

          private

          def invoke_service(method_name, args: nil, timeout:, on_result:)
            runtime_page&.invoke(self, method_name, args: args, timeout: timeout, on_result: on_result)
          end

          def compact_args(hash)
            hash.each_with_object({}) { |(key, value), result| result[key] = normalize_value(value) unless value.nil? }
          end

          def normalize_value(value)
            case value
            when Array then value.map { |item| normalize_value(item) }
            when Hash
              value.each_with_object({}) { |(key, item), result| result[key.to_s] = normalize_value(item) unless item.nil? }
            else
              value.respond_to?(:to_h) ? normalize_value(value.to_h) : value
            end
          end
        end
      end
    end
  end
end
