# frozen_string_literal: true

require_relative "test_helper"

class PageWindowServiceTest < Minitest::Test
  def test_window_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.window(width: 640, height: 480, always_on_top: true, key: "main_window")

    assert_equal "window", service.type
    assert_equal "Window", service.to_patch["_c"]
    assert_equal 640, service.props["width"]
    assert_equal 480, service.props["height"]
    assert_equal true, service.props["always_on_top"]
    assert_equal "main_window", service.props["key"]
    assert_same service, page.service(:window)
  end

  def test_window_methods_use_flet_method_names
    {
      wait_until_ready_to_show: "wait_until_ready_to_show",
      window_to_front: "to_front",
      center_window: "center",
      close_window: "close",
      destroy_window: "destroy",
      start_window_dragging: "start_dragging"
    }.each do |ruby_method, flet_method|
      sent = []
      page = build_page(sent)

      call_id = page.public_send(ruby_method)
      refute_nil call_id

      invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == flet_method }
      refute_nil invoke_payload
      assert_nil invoke_payload["args"]
    end
  end

  def test_window_start_resizing_uses_flet_edge_arg
    sent = []
    page = build_page(sent)

    call_id = page.start_window_resizing("right")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "start_resizing" }
    refute_nil invoke_payload
    assert_equal({ "edge" => "right" }, invoke_payload["args"])
  end

  def test_window_object_methods_match_flet_api
    {
      wait_until_ready_to_show: "wait_until_ready_to_show",
      to_front: "to_front",
      center: "center",
      close: "close",
      destroy: "destroy",
      start_dragging: "start_dragging"
    }.each do |ruby_method, flet_method|
      sent = []
      page = build_page(sent)
      window = page.window

      call_id = window.public_send(ruby_method)
      refute_nil call_id

      invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == flet_method }
      refute_nil invoke_payload
      assert_nil invoke_payload["args"]
    end
  end

  def test_window_object_start_resizing_uses_flet_edge_arg
    sent = []
    page = build_page(sent)
    window = page.window

    call_id = window.start_resizing("bottom_right")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "start_resizing" }
    refute_nil invoke_payload
    assert_equal({ "edge" => "bottom_right" }, invoke_payload["args"])
  end

  private

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end
end
