# frozen_string_literal: true

require_relative "test_helper"

class PageClipboardTest < Minitest::Test
  def test_set_clipboard_uses_flet_clipboard_set_signature
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.set_clipboard("hello")

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "set" }
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

    page.set_clipboard_image("abc123")

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "set_image" }
    refute_nil invoke_payload
    assert_equal({ "data" => "abc123" }, invoke_payload["args"])
  end
end
