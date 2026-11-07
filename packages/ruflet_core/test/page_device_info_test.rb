# frozen_string_literal: true

require_relative "test_helper"

# Flet's page.get_device_info() and page.set_allowed_device_orientations():
# Page methods (control id 1) the client's Page control answers.
class RufletPageDeviceInfoTest < Minitest::Test
  ANDROID_RECORD = {
    "model" => "Pixel 8",
    "display" => "AP2A.240905.003",
    "is_physical_device" => true,
    "version" => { "sdk" => 35, "release" => "15" },
    "locales" => [{ "language_code" => "en", "country_code" => "US" }]
  }.freeze

  def page_for(client_details)
    @sent = []
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" }.merge(client_details),
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def invokes
    @sent.select { |action, _payload| action == Ruflet::Protocol::ACTIONS[:invoke_control_method] }.map(&:last)
  end

  def test_get_device_info_invokes_the_page_and_wraps_the_record
    page = page_for("platform" => "android")
    answers = []

    call_id = page.get_device_info(on_result: ->(info, error) { answers << [info, error] })

    invoke = invokes.last
    assert_equal 1, invoke["control_id"]
    assert_equal "get_device_info", invoke["name"]
    assert_nil invoke["args"]
    assert_equal 10, invoke["timeout"]
    assert_equal call_id, invoke["call_id"]

    page.handle_invoke_method_result("call_id" => call_id, "result" => ANDROID_RECORD, "error" => nil)

    info, error = answers.fetch(0)
    assert_nil error
    assert_instance_of Ruflet::DeviceInfo, info
    assert_equal "android", info.platform
    assert info.android?
    refute info.web?
    assert_equal "Pixel 8", info.model
    assert_equal "Pixel 8", info["model"]
    assert_equal "Pixel 8", info[:model]
    assert_equal "AP2A.240905.003", info.display
    assert_equal 35, info.version["sdk"]
    assert_equal "en", info.locales.first["language_code"]
    assert info.respond_to?(:is_physical_device)
    refute info.respond_to?(:bootloader)
    assert_raises(NoMethodError) { info.bootloader }
    assert_equal ANDROID_RECORD, info.to_h
  end

  def test_web_clients_get_a_web_record_whose_own_platform_field_stays_reachable
    page = page_for("platform" => "macos", "web" => true)
    answers = []
    call_id = page.get_device_info(on_result: ->(info, error) { answers << [info, error] })

    page.handle_invoke_method_result(
      "call_id" => call_id,
      "result" => { "browser_name" => "safari", "platform" => "MacIntel", "user_agent" => "Mozilla" }
    )

    info = answers.fetch(0).first
    assert_equal "web", info.platform
    assert info.web?
    refute info.macos?
    assert_equal "MacIntel", info["platform"]
    assert_equal "safari", info.browser_name
  end

  def test_errors_and_empty_records_reach_the_callback_as_nil_info
    page = page_for("platform" => "fuchsia")
    answers = []
    first = page.get_device_info(on_result: ->(info, error) { answers << [info, error] })
    second = page.get_device_info(on_result: ->(info, error) { answers << [info, error] })

    page.handle_invoke_method_result("call_id" => first, "result" => {}, "error" => nil)
    page.handle_invoke_method_result("call_id" => second, "result" => nil, "error" => "boom")

    assert_equal [[nil, nil], [nil, "boom"]], answers
  end

  def test_get_device_info_without_a_callback_only_sends_the_call
    page = page_for("platform" => "ios")

    call_id = page.get_device_info(timeout: 3)

    assert_equal call_id, invokes.last["call_id"]
    assert_equal 3, invokes.last["timeout"]
    assert page.handle_invoke_method_result("call_id" => call_id, "result" => ANDROID_RECORD) == false
  end

  def test_get_device_info_sync_waits_for_the_client_answer
    page = page_for("platform" => "ios")
    responder = Thread.new do
      call = nil
      200.times do
        call = invokes.last
        break if call

        sleep 0.01
      end
      page.handle_invoke_method_result(
        "call_id" => call["call_id"],
        "result" => { "model" => "iPhone", "utsname" => { "machine" => "iPhone16,1" } }
      )
    end

    info = page.get_device_info_sync(timeout: 2)
    responder.join

    assert_equal "get_device_info", invokes.last["name"]
    assert_equal 1, invokes.last["control_id"]
    assert_equal "ios", info.platform
    assert info.ios?
    assert_equal "iPhone16,1", info.utsname["machine"]
  end

  def test_get_device_info_sync_raises_the_client_error
    page = page_for("platform" => "ios")
    responder = Thread.new do
      sleep 0.01 until invokes.last
      page.handle_invoke_method_result("call_id" => invokes.last["call_id"], "error" => "no record")
    end

    error = assert_raises(RuntimeError) { page.get_device_info_sync(timeout: 2) }
    responder.join
    assert_equal "no record", error.message
  end

  def test_set_allowed_device_orientations_sends_flet_wire_values
    page = page_for("platform" => "android")

    page.set_allowed_device_orientations(
      [:portrait_up, "landscape_left", Ruflet::DeviceOrientation::LANDSCAPE_RIGHT, "PORTRAIT_DOWN", :portrait_up]
    )
    page.set_allowed_device_orientations([])

    assert_equal %w[set_allowed_device_orientations set_allowed_device_orientations], invokes.map { |i| i["name"] }
    assert_equal [1, 1], invokes.map { |i| i["control_id"] }
    assert_equal({ "orientations" => %w[portraitUp landscapeLeft landscapeRight portraitDown] }, invokes.first["args"])
    assert_equal({ "orientations" => [] }, invokes.last["args"])
  end

  def test_set_allowed_device_orientations_reports_the_client_answer
    page = page_for("platform" => "ios")
    answers = []
    call_id = page.set_allowed_device_orientations(:portrait_up, on_result: ->(result, error) { answers << [result, error] })

    page.handle_invoke_method_result("call_id" => call_id, "result" => nil, "error" => nil)

    assert_equal({ "orientations" => ["portraitUp"] }, invokes.last["args"])
    assert_equal [[nil, nil]], answers
  end

  def test_set_allowed_device_orientations_rejects_unknown_names_before_sending
    page = page_for("platform" => "android")

    error = assert_raises(ArgumentError) { page.set_allowed_device_orientations([:portrait_up, :sideways]) }

    assert_includes error.message, ":sideways"
    assert_includes error.message, "landscape_left"
    assert_empty invokes
  end

  def test_set_allowed_device_orientations_raises_on_non_mobile_clients
    [
      { "platform" => "macos" },
      { "platform" => "windows" },
      { "platform" => "linux" },
      { "platform" => "android_tv" },
      { "platform" => "android", "web" => true }
    ].each do |details|
      page = page_for(details)

      error = assert_raises(Ruflet::UnsupportedPlatformError, details.inspect) do
        page.set_allowed_device_orientations([:portrait_up])
      end
      assert_equal "set_allowed_device_orientations is only supported on mobile platforms", error.message
      assert_empty invokes, details.inspect
    end
  end

  def test_a_client_that_did_not_report_its_platform_answers_for_itself
    page = page_for({})

    page.set_allowed_device_orientations([:landscape_left])

    assert_equal({ "orientations" => ["landscapeLeft"] }, invokes.last["args"])
  end

  def test_device_orientation_names_flet_values
    assert_equal %w[portraitUp portraitDown landscapeLeft landscapeRight], Ruflet::DeviceOrientation::ALL
    assert_equal "landscapeRight", Ruflet::DeviceOrientation.wire_value(:landscape_right)
    assert_raises(ArgumentError) { Ruflet::DeviceOrientation.wire_value(nil) }
  end
end
