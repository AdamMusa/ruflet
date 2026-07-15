# frozen_string_literal: true

require_relative "test_helper"

class PageTesterServiceTest < Minitest::Test
  def test_tester_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.tester(data: { "source" => "studio" }, key: "tester")

    assert_equal "tester", service.type
    assert_equal "Tester", service.to_patch["_c"]
    assert_equal({ "source" => "studio" }, service.props["data"])
    assert_equal "tester", service.props["key"]
    assert_same service, page.service(:tester)
  end

  def test_tester_find_methods_use_flet_payload_shape
    {
      [:find_by_text, ["OK"]] => ["find_by_text", { "text" => "OK" }],
      [:find_by_text_containing, ["OK"]] => ["find_by_text_containing", { "pattern" => "OK" }],
      [:find_by_key, ["submit"]] => ["find_by_key", { "key" => "submit" }],
      [:find_by_tooltip, ["Help"]] => ["find_by_tooltip", { "value" => "Help" }],
      [:find_by_icon, ["add"]] => ["find_by_icon", { "icon" => "add" }]
    }.each do |(ruby_method, args), (flet_method, flet_args)|
      sent = []
      page = build_page(sent)

      call_id = page.public_send(ruby_method, *args)
      refute_nil call_id

      invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == flet_method }
      refute_nil invoke_payload
      assert_equal flet_args, invoke_payload["args"]
    end
  end

  def test_tester_action_methods_use_flet_payload_shape
    {
      [:tester_pump, []] => ["pump", {}],
      [:tester_pump, [{ duration: 100 }]] => ["pump", { "duration" => 100 }],
      [:tester_pump_and_settle, [{ duration: 250 }]] => ["pump_and_settle", { "duration" => 250 }],
      [:take_screenshot, ["smoke"]] => ["take_screenshot", { "name" => "smoke" }],
      [:tap, ["finder-1"]] => ["tap", { "finder_id" => "finder-1" }],
      [:tap, ["finder-1", { finder_index: 2 }]] => ["tap", { "finder_id" => "finder-1", "finder_index" => 2 }],
      [:tap_at, [{ x: 12, y: 24 }]] => ["tap_at", { "offset" => { "x" => 12, "y" => 24 } }],
      [:drag, ["finder-1", { x: 10, y: 20 }]] => ["drag", { "finder_id" => "finder-1", "offset" => { "x" => 10, "y" => 20 } }],
      [:drag_from, [{ x: 1, y: 2 }, { x: 3, y: 4 }]] => ["drag_from", { "start" => { "x" => 1, "y" => 2 }, "offset" => { "x" => 3, "y" => 4 } }],
      [:enter_text, ["finder-1", "hello"]] => ["enter_text", { "finder_id" => "finder-1", "text" => "hello" }]
    }.each do |(ruby_method, args), (flet_method, flet_args)|
      sent = []
      page = build_page(sent)

      call_id = page.public_send(ruby_method, *args)
      refute_nil call_id

      invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == flet_method }
      refute_nil invoke_payload
      assert_equal flet_args, invoke_payload["args"]
    end
  end

  def test_tester_pointer_aliases_use_flet_method_names
    %i[
      mouse_click
      mouse_double_click
      right_mouse_click
      mouse_click_at
      mouse_double_click_at
      right_mouse_click_at
      long_press
      mouse_hover
      tester_teardown
    ].each do |ruby_method|
      sent = []
      page = build_page(sent)
      flet_method = ruby_method.to_s.delete_prefix("tester_")

      call_id = page.public_send(ruby_method)
      refute_nil call_id

      invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == flet_method }
      refute_nil invoke_payload
    end
  end

  def test_tester_object_methods_match_flet_api
    sent = []
    page = build_page(sent)
    tester = page.tester

    tester.pump(duration: 100)
    tester.find_by_text("OK")
    tester.tap("finder-1", finder_index: 2)
    tester.drag_from({ x: 1, y: 2 }, { x: 3, y: 4 })
    tester.teardown

    payloads = sent.map(&:last)
    assert_equal({ "duration" => 100 }, payloads.find { |payload| payload["name"] == "pump" }["args"])
    assert_equal({ "text" => "OK" }, payloads.find { |payload| payload["name"] == "find_by_text" }["args"])
    assert_equal(
      { "finder_id" => "finder-1", "finder_index" => 2 },
      payloads.find { |payload| payload["name"] == "tap" }["args"]
    )
    assert_equal(
      { "start" => { "x" => 1, "y" => 2 }, "offset" => { "x" => 3, "y" => 4 } },
      payloads.find { |payload| payload["name"] == "drag_from" }["args"]
    )
    assert_nil payloads.find { |payload| payload["name"] == "teardown" }["args"]
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
