# frozen_string_literal: true

require_relative "test_helper"

class PageLocalAuthenticationServiceTest < Minitest::Test
  LocalAuthenticationControl = Ruflet::UI::Services::RufletServicesComponents::LocalAuthenticationControl
  Messages = Struct.new(:cancel_button, :localized_fallback_title)

  def setup
    @sent = []
    # Replies the client would send, keyed by invoke method name. The fake
    # sender answers synchronously, as the client's reply would arrive on the
    # connection's reader thread while a *_sync caller waits.
    @replies = {}
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: lambda do |action, payload|
        @sent << [action, payload]
        reply = @replies[payload["name"]] if payload.is_a?(Hash)
        @page.handle_invoke_method_result(reply.merge("call_id" => payload["call_id"])) if reply
      end
    )
    Ruflet::DSL._reset_pending_app!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  # --- service registration -------------------------------------------------

  def test_page_helpers_return_one_typed_service_with_the_engine_wire_type
    service = @page.local_authentication(data: { "source" => "studio" }, key: "auth")

    assert_instance_of LocalAuthenticationControl, service
    assert_equal "localauthentication", service.type
    assert_equal "LocalAuthentication", service.to_patch["_c"]
    assert_equal({ "source" => "studio" }, service.props["data"])
    assert_equal "auth", service.props["key"]
    assert_same service, @page.local_auth
    assert_same service, @page.service(:local_authentication)
    assert_same service, @page.service(:localauthentication)
    assert_equal 1, @page.services.count { |s| s.is_a?(LocalAuthenticationControl) }
  end

  def test_registry_service_types_and_dsl_helpers
    assert_same LocalAuthenticationControl, Ruflet::UI::Services::RufletServices::CLASS_MAP["local_authentication"]
    assert_same LocalAuthenticationControl, Ruflet::UI::Services::RufletServices::CLASS_MAP["localauthentication"]
    assert_instance_of LocalAuthenticationControl, Ruflet::UI::ControlFactory.build("local_authentication")
    assert Ruflet::UI::ServiceTypes.service_wire_type?("LocalAuthentication")
    assert Ruflet::UI::ServiceTypes.service_name?("local_authentication")
    assert Ruflet::UI::ServiceTypes.service_name?("localauthentication")
    assert Ruflet::Page::PRESENTED_TYPES.key?("LocalAuthentication")
    assert_equal %i[data key], LocalAuthenticationControl::KEYWORDS

    %i[local_auth local_authentication].each do |helper|
      assert_respond_to Ruflet::DSL, helper
      assert_respond_to @page, helper
    end
    service = Ruflet::DSL.local_auth
    assert_instance_of LocalAuthenticationControl, service
    assert_includes Ruflet.app.instance_variable_get(:@services), service
  end

  def test_dsl_blocks_do_not_lay_out_the_service
    column = Ruflet.column do
      local_authentication
      text("Unlock")
    end

    assert_equal %w[text], column.children.map(&:type)
  end

  # --- invoke payloads ------------------------------------------------------

  def test_authenticate_sends_the_reason_and_local_auth_defaults
    service = @page.local_auth
    call_id = service.authenticate(localized_reason: "Unlock your notes", on_result: ->(*) {})

    payload = last_invoke
    assert_equal call_id, payload["call_id"]
    assert_equal service.wire_id, payload["control_id"]
    assert_equal "authenticate", payload["name"]
    assert_equal(
      {
        "localized_reason" => "Unlock your notes",
        "biometric_only" => false,
        "sensitive_transaction" => true,
        "persist_across_backgrounding" => false
      },
      payload["args"]
    )
    assert_equal 60, payload["timeout"]
  end

  def test_authenticate_sends_options_and_normalized_dialog_messages
    @page.local_auth.authenticate(
      localized_reason: :pay,
      biometric_only: true,
      sensitive_transaction: false,
      persist_across_backgrounding: 1,
      android_messages: { sign_in_title: "Pay", sign_in_hint: nil, cancel_button: :cancel },
      ios_messages: Messages.new("Later", "Use passcode"),
      macos_messages: { "cancel_button" => "Stop" },
      timeout: 120
    )

    payload = last_invoke
    assert_equal(
      {
        "localized_reason" => "pay",
        "biometric_only" => true,
        "sensitive_transaction" => false,
        "persist_across_backgrounding" => true,
        "android_messages" => { "sign_in_title" => "Pay", "cancel_button" => "cancel" },
        "ios_messages" => { "cancel_button" => "Later", "localized_fallback_title" => "Use passcode" },
        "macos_messages" => { "cancel_button" => "Stop" }
      },
      payload["args"]
    )
    assert_equal 120, payload["timeout"]
  end

  def test_authenticate_requires_a_reason
    assert_raises(ArgumentError) { @page.local_auth.authenticate }
    assert_raises(ArgumentError) { @page.local_auth.authenticate_sync }
  end

  def test_queries_send_no_args_and_the_default_timeout
    service = @page.local_auth
    %w[can_check_biometrics is_device_supported get_available_biometrics stop_authentication].each do |method_name|
      call_id = service.public_send(method_name)

      payload = last_invoke
      refute_nil call_id
      assert_equal call_id, payload["call_id"]
      assert_equal service.wire_id, payload["control_id"]
      assert_equal method_name, payload["name"]
      assert_nil payload["args"]
      assert_equal 10, payload["timeout"]
    end

    service.device_supported?(timeout: 3)
    assert_equal "is_device_supported", last_invoke["name"]
    assert_equal 3, last_invoke["timeout"]
  end

  # --- results and errors ---------------------------------------------------

  def test_on_result_receives_the_client_result
    results = []
    call_id = @page.local_auth.get_available_biometrics(on_result: ->(result, error) { results << [result, error] })

    assert @page.handle_invoke_method_result("call_id" => call_id, "result" => %w[face fingerprint])
    assert_equal [[%w[face fingerprint], nil]], results
  end

  def test_on_result_receives_the_client_error_which_local_auth_error_parses
    errors = []
    call_id = @page.local_auth.authenticate(localized_reason: "Unlock", on_result: ->(_result, error) { errors << error })
    message = "LocalAuthentication.authenticate failed [user_canceled]: The user canceled authentication."

    @page.handle_invoke_method_result("call_id" => call_id, "result" => nil, "error" => message)

    assert_equal [message], errors
    error = Ruflet::LocalAuthError.from_error(errors.first)
    assert_equal "user_canceled", error.code
    assert_equal "authenticate", error.method_name
    assert_equal "The user canceled authentication.", error.description
    assert_equal message, error.message
  end

  def test_sync_forms_return_the_client_result
    service = @page.local_auth
    @replies["authenticate"] = { "result" => true }
    @replies["can_check_biometrics"] = { "result" => true }
    @replies["is_device_supported"] = { "result" => false }
    @replies["get_available_biometrics"] = { "result" => %w[face] }
    @replies["stop_authentication"] = { "result" => true }

    assert_equal true, service.authenticate_sync(localized_reason: "Unlock", biometric_only: true)
    payload = last_invoke
    assert_equal "authenticate", payload["name"]
    assert_equal service.wire_id, payload["control_id"]
    assert_equal true, payload.dig("args", "biometric_only")
    assert_equal 60, payload["timeout"]

    assert_equal true, service.can_check_biometrics_sync
    assert_equal false, service.is_device_supported_sync(timeout: 5)
    assert_equal 5, last_invoke["timeout"]
    assert_nil last_invoke["args"]
    assert_equal %w[face], service.get_available_biometrics_sync
    assert_equal true, service.stop_authentication_sync
  end

  def test_sync_forms_raise_local_auth_error_with_the_code
    @replies["authenticate"] = {
      "error" => "LocalAuthentication.authenticate failed [no_biometrics_enrolled]: No biometrics are enrolled on this device."
    }
    @replies["is_device_supported"] = {
      "error" => "LocalAuthentication.is_device_supported failed [NotAvailable]: No passcode set"
    }
    @replies["can_check_biometrics"] = {
      "error" => "Unsupported operation: LocalAuthentication(5).can_check_biometrics is not supported on linux"
    }

    error = assert_raises(Ruflet::LocalAuthError) do
      @page.local_auth.authenticate_sync(localized_reason: "Unlock", biometric_only: true)
    end
    assert_equal "no_biometrics_enrolled", error.code
    assert_equal "authenticate", error.method_name
    assert_equal "No biometrics are enrolled on this device.", error.description
    assert_kind_of StandardError, error

    error = assert_raises(Ruflet::LocalAuthError) { @page.local_auth.is_device_supported_sync }
    assert_equal "NotAvailable", error.code
    assert_equal "No passcode set", error.description

    error = assert_raises(Ruflet::LocalAuthError) { @page.local_auth.can_check_biometrics_sync }
    assert_nil error.code
    assert_nil error.method_name
    assert_includes error.message, "is not supported on linux"
  end

  def test_sync_timeout_is_not_reported_as_a_local_auth_error
    assert_raises(Timeout::Error) { @page.local_auth.get_available_biometrics_sync(timeout: 0.05) }
  end

  def test_local_auth_error_parses_messages_without_a_description
    error = Ruflet::LocalAuthError.from_error("LocalAuthentication.stop_authentication failed [channel-error]")

    assert_equal "channel-error", error.code
    assert_equal "stop_authentication", error.method_name
    assert_equal "", error.description
  end

  private

  def last_invoke
    @sent.reverse.map(&:last).find { |payload| payload.is_a?(Hash) && payload.key?("call_id") }
  end
end
