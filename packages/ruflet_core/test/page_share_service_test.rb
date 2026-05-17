# frozen_string_literal: true

require_relative "test_helper"

class PageShareServiceTest < Minitest::Test
  def test_share_text_accepts_positional_text_and_omits_nil_options
    sent = []
    page = build_page(sent)

    call_id = page.share_text("Hello from Ruflet", title: "Greeting")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "share_text" }
    refute_nil invoke_payload
    assert_equal(
      {
        "text" => "Hello from Ruflet",
        "title" => "Greeting",
        "download_fallback_enabled" => true,
        "mail_to_fallback_enabled" => true
      },
      invoke_payload["args"]
    )
  end

  def test_share_uri_accepts_positional_uri_and_omits_nil_options
    sent = []
    page = build_page(sent)

    call_id = page.share_uri("https://flet.dev")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "share_uri" }
    refute_nil invoke_payload
    assert_equal({ "uri" => "https://flet.dev" }, invoke_payload["args"])
  end

  def test_share_files_accepts_positional_files_and_normalizes_file_hashes
    sent = []
    page = build_page(sent)

    files = [{ path: "/tmp/a.txt", name: "a.txt" }]
    call_id = page.share_files(files, text: "Attachment")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "share_files" }
    refute_nil invoke_payload
    assert_equal(
      {
        "files" => [{ "path" => "/tmp/a.txt", "name" => "a.txt" }],
        "text" => "Attachment",
        "download_fallback_enabled" => true,
        "mail_to_fallback_enabled" => true
      },
      invoke_payload["args"]
    )
  end

  def test_share_files_converts_data_byte_arrays_to_binary_strings
    sent = []
    page = build_page(sent)

    call_id = page.share_files([{ data: [0, 255], name: "sample.bin" }])
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "share_files" }
    refute_nil invoke_payload
    data = invoke_payload.dig("args", "files", 0, "data")

    assert_equal "\x00\xff".b, data
    assert_equal Encoding::BINARY, data.encoding
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
