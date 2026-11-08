# frozen_string_literal: true

module Ruflet
  # A failed LocalAuthentication invoke. The engine reports the local_auth
  # plugin's failures as
  #
  #   LocalAuthentication.authenticate failed [user_canceled]: The user canceled authentication.
  #
  # #code is the snake_case local_auth error code (user_canceled,
  # no_biometrics_enrolled, temporary_lockout, ...) or a platform error code
  # as the platform reported it; it is nil for errors that do not come from
  # the plugin, such as an unsupported platform or a missing argument.
  class LocalAuthError < StandardError
    MARKER = " failed [".freeze

    attr_reader :code, :method_name, :description

    # Builds the error from an invoke's error string (what on_result receives
    # as its second argument).
    def self.from_error(error)
      text = error.to_s
      marker = text.index(MARKER)
      closing = marker && text.index("]", marker + MARKER.length)
      return new(text) unless marker && closing

      method_name = text[0, marker]
      dot = method_name.index(".")
      method_name = method_name[dot + 1, method_name.length] if dot
      code = text[marker + MARKER.length, closing - marker - MARKER.length]
      description = text[closing + 1, text.length].to_s
      description = description[2, description.length].to_s if description.start_with?(": ")
      new(text, code: code, method_name: method_name, description: description)
    end

    def initialize(message = nil, code: nil, method_name: nil, description: nil)
      super(message)
      @code = code
      @method_name = method_name
      @description = description || message
    end
  end

  module UI
    module Services
      module RufletServicesComponents
        # Device authentication with biometrics or the device credential
        # (PIN, pattern, passcode) through Flutter's local_auth plugin. The
        # client needs the `local_auth` extension (ruflet.yaml `extensions:`)
        # or the `biometrics` service (services.yaml).
        #
        # Every method is asynchronous and returns the invoke's call id; the
        # result arrives in `on_result.call(result, error)`. Each also has a
        # `*_sync` form that blocks the calling thread until the client
        # answers and returns the result or raises Ruflet::LocalAuthError.
        # Event handlers run on the connection's reader thread, which also
        # delivers the answer, so call a `*_sync` method from another thread
        # (or use on_result) rather than directly inside a handler.
        class LocalAuthenticationControl < Ruflet::Control
          TYPE = "localauthentication".freeze
          WIRE = "LocalAuthentication".freeze
          KEYWORDS = [:data, :key].freeze
          # The prompt waits for the user, so it gets longer than the usual
          # 10 seconds before Ruby gives up on the answer.
          AUTHENTICATE_TIMEOUT = 60
          QUERY_METHODS = %w[can_check_biometrics is_device_supported get_available_biometrics stop_authentication].freeze

          def initialize(id: nil, data: nil, key: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end

          # Prompts the user to authenticate. The result is true on success
          # and false when the user failed the challenge; cancellation,
          # lockout and missing hardware or credentials arrive as the error.
          #
          # android_messages: { sign_in_title:, sign_in_hint:, cancel_button: }
          # ios_messages / macos_messages: { cancel_button:, localized_fallback_title: }
          def authenticate(localized_reason:, biometric_only: false, sensitive_transaction: true,
                           persist_across_backgrounding: false, android_messages: nil,
                           ios_messages: nil, macos_messages: nil,
                           timeout: AUTHENTICATE_TIMEOUT, on_result: nil)
            args = authenticate_args(
              localized_reason, biometric_only, sensitive_transaction, persist_across_backgrounding,
              android_messages, ios_messages, macos_messages
            )
            invoke_local_auth("authenticate", args, timeout, on_result)
          end

          def authenticate_sync(localized_reason:, biometric_only: false, sensitive_transaction: true,
                                persist_across_backgrounding: false, android_messages: nil,
                                ios_messages: nil, macos_messages: nil, timeout: AUTHENTICATE_TIMEOUT)
            args = authenticate_args(
              localized_reason, biometric_only, sensitive_transaction, persist_across_backgrounding,
              android_messages, ios_messages, macos_messages
            )
            invoke_local_auth_sync("authenticate", args, timeout)
          end

          # can_check_biometrics: whether the device has biometric hardware.
          # is_device_supported: whether it can authenticate with biometrics
          #   or the device credential.
          # get_available_biometrics: enrolled biometrics the app may use, as
          #   strings: "face", "fingerprint", "iris", "strong", "weak".
          # stop_authentication: cancels a prompt in progress (Android).
          QUERY_METHODS.each do |method_name|
            define_method(method_name) do |timeout: 10, on_result: nil|
              invoke_local_auth(method_name, nil, timeout, on_result)
            end

            define_method("#{method_name}_sync") do |timeout: 10|
              invoke_local_auth_sync(method_name, nil, timeout)
            end
          end

          def device_supported?(timeout: 10, on_result: nil)
            is_device_supported(timeout: timeout, on_result: on_result)
          end

          private

          def authenticate_args(localized_reason, biometric_only, sensitive_transaction,
                                persist_across_backgrounding, android_messages, ios_messages,
                                macos_messages)
            args = {
              "localized_reason" => localized_reason.to_s,
              "biometric_only" => biometric_only ? true : false,
              "sensitive_transaction" => sensitive_transaction ? true : false,
              "persist_across_backgrounding" => persist_across_backgrounding ? true : false
            }
            {
              "android_messages" => android_messages,
              "ios_messages" => ios_messages,
              "macos_messages" => macos_messages
            }.each do |key, messages|
              args[key] = normalize_messages(messages) unless messages.nil?
            end
            args
          end

          def invoke_local_auth(method_name, args, timeout, on_result)
            runtime_page&.invoke(self, method_name, args: args, timeout: timeout, on_result: on_result)
          end

          def invoke_local_auth_sync(method_name, args, timeout)
            page = runtime_page
            return nil unless page

            begin
              page.invoke_sync(self, method_name, args: args, timeout: timeout)
            rescue RuntimeError => e
              # invoke_sync raises a plain RuntimeError carrying the client's
              # error; a timeout (Timeout::Error) passes through unchanged.
              raise e unless e.instance_of?(RuntimeError)

              raise LocalAuthError.from_error(e.message)
            end
          end

          def normalize_messages(messages)
            messages = messages.to_h unless messages.is_a?(Hash)
            messages.each_with_object({}) do |(key, value), result|
              result[key.to_s] = value.to_s unless value.nil?
            end
          end
        end
      end
    end
  end
end
