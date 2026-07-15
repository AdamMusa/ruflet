# frozen_string_literal: true

require_relative "test_helper"

class PageWindowTest < Minitest::Test
  WINDOW_SNAPSHOT = {
    "_c" => "Window",
    "_i" => 2,
    "width" => 1280.0,
    "height" => 720.0,
    "visible" => true,
    "focused" => true
  }.freeze

  def test_page_owns_the_client_window_with_flets_reserved_wire_id
    sent = []
    page = build_page(sent)

    assert_instance_of Ruflet::UI::Controls::RufletComponents::WindowControl, page.window
    assert_equal 2, page.window.wire_id
    assert_equal 1280.0, page.window.props["width"]

    page.add(Ruflet.text(value: "Ready"))
    page_patch = sent.last.last.fetch("patch")
    window_patch = page_patch.find { |operation| operation[2] == "window" }
    assert_equal "Window", window_patch[3]["_c"]
    assert_equal 2, window_patch[3]["_i"]
  end

  def test_register_payload_preserves_the_clients_native_window_snapshot
    normalized = Ruflet::Protocol.normalize_register_payload(
      "page" => { "route" => "/", "window" => WINDOW_SNAPSHOT }
    )

    assert_equal WINDOW_SNAPSHOT, normalized["window"]
  end

  def test_window_properties_update_the_existing_native_window_control
    sent = []
    page = build_page(sent)

    page.update(page.window, width: 900, height: 700, resizable: false)

    action, payload = sent.last
    assert_equal Ruflet::Protocol::ACTIONS[:patch_control], action
    assert_equal 2, payload["id"]
    assert_equal [
      [0],
      [0, 0, "width", 900],
      [0, 0, "height", 700],
      [0, 0, "resizable", false]
    ], payload["patch"]
  end

  def test_window_methods_match_flets_window_protocol
    sent = []
    page = build_page(sent)

    %w[
      wait_until_ready_to_show
      destroy
      center
      close
      to_front
      start_dragging
    ].each do |method_name|
      page.window.public_send(method_name, timeout: 3)
      assert_window_invoke sent.last, method_name, nil, 3
    end

    page.window.start_resizing(:bottom_right, timeout: 4)
    assert_window_invoke sent.last, "start_resizing", { "edge" => "bottomRight" }, 4
  end

  def test_window_events_are_dispatched_to_page_window
    events = []
    page = build_page([])
    page.window.on(:event) { |event| events << event.data }
    page.add(Ruflet.text(value: "Ready"))

    page.dispatch_event(target: 2, name: "event", data: "maximize")

    assert_equal ["maximize"], events
  end

  private

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "window-session",
      client_details: { "route" => "/", "window" => WINDOW_SNAPSHOT },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end

  def assert_window_invoke(message, name, args, timeout)
    action, payload = message
    assert_equal Ruflet::Protocol::ACTIONS[:invoke_control_method], action
    assert_equal 2, payload["control_id"]
    assert_equal name, payload["name"]
    args.nil? ? assert_nil(payload["args"]) : assert_equal(args, payload["args"])
    assert_equal timeout, payload["timeout"]
  end
end
