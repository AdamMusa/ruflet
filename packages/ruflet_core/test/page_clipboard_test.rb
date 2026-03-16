# frozen_string_literal: true

require_relative "test_helper"

class PageClipboardTest < Minitest::Test
  def test_set_clipboard_uses_flet_clipboard_set_data_signature
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    call_id = page.set_clipboard("hello")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "set_data" }
    refute_nil invoke_payload
    assert_equal({ "data" => "hello" }, invoke_payload["args"])
  end

  def test_set_clipboard_image_uses_data_key
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    call_id = page.set_clipboard_image("abc123")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "set_image" }
    refute_nil invoke_payload
    assert_equal({ "data" => "abc123" }, invoke_payload["args"])
  end

  def test_launch_url_uses_url_launcher_service_signature
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    call_id = page.launch_url("https://flet.dev")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "launch_url" }
    refute_nil invoke_payload
    refute_equal 1, invoke_payload["control_id"]
    assert_equal "https://flet.dev", invoke_payload.dig("args", "url")
  end
end
