# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class SecureStorageControl < Ruflet::Control
          TYPE = "securestorage".freeze
          WIRE = "SecureStorage".freeze
          KEYWORDS = [:android_options, :data, :ios_options, :key, :macos_options, :web_options, :windows_options, :on_change].freeze
          OPTION_KEYS = %w[web ios macos android windows].freeze

          def initialize(id: nil, android_options: nil, data: nil, ios_options: nil, key: nil, macos_options: nil, web_options: nil, windows_options: nil, on_change: nil)
            props = {}
            props[:android_options] = android_options unless android_options.nil?
            props[:data] = data unless data.nil?
            props[:ios_options] = ios_options unless ios_options.nil?
            props[:key] = key unless key.nil?
            props[:macos_options] = macos_options unless macos_options.nil?
            props[:web_options] = web_options unless web_options.nil?
            props[:windows_options] = windows_options unless windows_options.nil?
            props[:on_change] = on_change unless on_change.nil?
            super(type: TYPE, id: id, **props)
          end

          def set(key, value, **options) = invoke_with_options("set", options, "key" => key, "value" => value)
          def get(key, **options) = invoke_with_options("get", options, "key" => key)
          def contains_key(key, **options) = invoke_with_options("contains_key", options, "key" => key)
          def get_all(**options) = invoke_with_options("get_all", options)
          def remove(key, **options) = invoke_with_options("remove", options, "key" => key)
          def clear(**options) = invoke_with_options("clear", options)

          def get_availability(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "get_availability", timeout: timeout, on_result: on_result)
          end

          private

          def invoke_with_options(method_name, options, args = {})
            OPTION_KEYS.each do |key|
              value = options[key.to_sym] || options[key]
              args[key] = normalize_value(value) unless value.nil?
            end
            runtime_page&.invoke(
              self,
              method_name,
              args: args,
              timeout: options.fetch(:timeout, 10),
              on_result: options[:on_result]
            )
          end

          def normalize_value(value)
            case value
            when Array then value.map { |item| normalize_value(item) }
            when Hash then value.each_with_object({}) { |(key, item), result| result[key.to_s] = normalize_value(item) unless item.nil? }
            else value.respond_to?(:to_h) ? normalize_value(value.to_h) : value
            end
          end
        end
      end
    end
  end
end
