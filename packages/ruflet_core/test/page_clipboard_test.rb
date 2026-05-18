# frozen_string_literal: true

require_relative "test_helper"

class PageClipboardTest < Minitest::Test
  def test_clipboard_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.clipboard(data: { "source" => "studio" }, key: "clipboard")

    assert_equal "clipboard", service.type
    assert_equal "Clipboard", service.to_patch["_c"]
    assert_equal({ "source" => "studio" }, service.props["data"])
    assert_equal "clipboard", service.props["key"]
    assert_same service, page.service(:clipboard)
  end

  def test_set_clipboard_uses_flet_clipboard_set_signature
    sent = []
    page = build_page(sent)

    call_id = page.set_clipboard("hello")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "set" }
    refute_nil invoke_payload
    assert_equal({ "data" => "hello" }, invoke_payload["args"])
  end

  def test_get_clipboard_uses_flet_clipboard_get_signature
    sent = []
    page = build_page(sent)

    call_id = page.get_clipboard
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "get" }
    refute_nil invoke_payload
    assert_nil invoke_payload["args"]
  end

  def test_set_clipboard_image_uses_data_key
    sent = []
    page = build_page(sent)

    call_id = page.set_clipboard_image("abc123")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "set_image" }
    refute_nil invoke_payload
    assert_equal({ "data" => "abc123" }, invoke_payload["args"])
  end

  def test_launch_url_uses_url_launcher_service_signature
    sent = []
    page = build_page(sent)

    call_id = page.launch_url("https://flet.dev")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "launch_url" }
    refute_nil invoke_payload
    refute_equal 1, invoke_payload["control_id"]
    assert_equal "https://flet.dev", invoke_payload.dig("args", "url")
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
