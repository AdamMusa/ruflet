# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class SecureStorageControl < Ruflet::Control
          TYPE = "securestorage".freeze
          WIRE = "SecureStorage".freeze
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

          def set(key, value, **options)
            raise ArgumentError, "value must not be nil" if value.nil?

            invoke_secure_storage("set", args: option_args(options).merge("key" => key, "value" => value), **invoke_options(options))
          end

          def get(key, **options)
            invoke_secure_storage("get", args: option_args(options).merge("key" => key), **invoke_options(options))
          end

          def contains_key(key, **options)
            invoke_secure_storage("contains_key", args: option_args(options).merge("key" => key), **invoke_options(options))
          end

          def get_all(**options)
            invoke_secure_storage("get_all", args: option_args(options), **invoke_options(options))
          end

          def remove(key, **options)
            invoke_secure_storage("remove", args: option_args(options).merge("key" => key), **invoke_options(options))
          end

          def clear(**options)
            invoke_secure_storage("clear", args: option_args(options), **invoke_options(options))
          end

          def get_availability(timeout: 10, on_result: nil)
            invoke_secure_storage("get_availability", timeout: timeout, on_result: on_result)
          end

          private

          def invoke_secure_storage(method_name, args: nil, timeout:, on_result:)
            runtime_page&.invoke(self, method_name, args: args, timeout: timeout, on_result: on_result)
          end

          def invoke_options(options)
            {
              timeout: options.fetch(:timeout, 10),
              on_result: options[:on_result]
            }
          end

          def option_args(options)
            OPTION_KEYS.each_with_object({}) do |key, result|
              value = options[key.to_sym] || options[key]
              result[key] = normalize_service_value(value) unless value.nil?
            end
          end

          def normalize_service_value(value)
            case value
            when Array
              value.map { |item| normalize_service_value(item) }
            when Hash
              value.transform_keys(&:to_s).each_with_object({}) do |(key, item), result|
                result[key] = normalize_service_value(item) unless item.nil?
              end
            else
              value.respond_to?(:to_h) ? normalize_service_value(value.to_h) : value
            end
          end
        end
      end
    end
  end
end
