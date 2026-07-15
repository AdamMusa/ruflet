# frozen_string_literal: true

require_relative "test_helper"

class PageBrowserContextMenuServiceTest < Minitest::Test
  def test_browser_context_menu_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.browser_context_menu(data: { "source" => "studio" }, key: "menu")

    assert_equal "browsercontextmenu", service.type
    assert_equal "BrowserContextMenu", service.to_patch["_c"]
    assert_equal({ "source" => "studio" }, service.props["data"])
    assert_equal "menu", service.props["key"]
    assert_same service, page.service(:browser_context_menu)
  end

  def test_browser_context_menu_methods_use_flet_method_names
    {
      disable_browser_context_menu: "disable_menu",
      enable_browser_context_menu: "enable_menu"
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

  def test_browser_context_menu_object_methods_match_flet_api_and_disabled_state
    sent = []
    page = build_page(sent)
    service = page.browser_context_menu

    service.disable
    disable_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "disable_menu" }
    refute_nil disable_payload
    assert_equal true, service.props["disabled"]

    service.enable
    enable_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "enable_menu" }
    refute_nil enable_payload
    assert_equal false, service.props["disabled"]
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
