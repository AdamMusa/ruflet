# frozen_string_literal: true

require_relative "test_helper"

class PageUrlLauncherServiceTest < Minitest::Test
  def test_url_launcher_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.url_launcher(data: { "source" => "studio" }, key: "launcher")

    assert_equal "urllauncher", service.type
    assert_equal "UrlLauncher", service.to_patch["_c"]
    assert_equal({ "source" => "studio" }, service.props["data"])
    assert_equal "launcher", service.props["key"]
    assert_same service, page.service(:url_launcher)
  end

  def test_close_in_app_web_view_uses_flet_url_launcher_signature
    sent = []
    page = build_page(sent)

    call_id = page.close_in_app_web_view
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "close_in_app_web_view" }
    refute_nil invoke_payload
    assert_nil invoke_payload["args"]
  end

  def test_open_window_uses_flet_url_launcher_signature
    sent = []
    page = build_page(sent)

    call_id = page.open_window("https://flet.dev", title: "Flet popup", width: 480, height: 640)
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "open_window" }
    refute_nil invoke_payload
    assert_equal(
      {
        "url" => "https://flet.dev",
        "title" => "Flet popup",
        "width" => 480,
        "height" => 640
      },
      invoke_payload["args"]
    )
  end

  def test_supports_launch_mode_uses_flet_url_launcher_signature
    sent = []
    page = build_page(sent)

    call_id = page.supports_launch_mode("in_app_web_view")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "supports_launch_mode" }
    refute_nil invoke_payload
    assert_equal({ "mode" => "in_app_web_view" }, invoke_payload["args"])
  end

  def test_supports_close_for_launch_mode_uses_flet_url_launcher_signature
    sent = []
    page = build_page(sent)

    call_id = page.supports_close_for_launch_mode("in_app_web_view")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "supports_close_for_launch_mode" }
    refute_nil invoke_payload
    assert_equal({ "mode" => "in_app_web_view" }, invoke_payload["args"])
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
