# frozen_string_literal: true

require_relative "test_helper"

class PageBrowserContextMenuServiceTest < Minitest::Test
  def test_browser_context_menu_is_a_page_service
    page, = build_page
    service = page.service(:browser_context_menu)

    assert_equal "BrowserContextMenu", service.to_patch["_c"]
    assert_includes page.services, service
    refute service.disabled
  end

  def test_enable_and_disable_use_current_flet_method_names
    page, sent = build_page
    service = page.service(:browser_context_menu)

    service.disable
    assert service.disabled?
    assert_equal "disable_menu", sent.last[1]["name"]

    service.enable
    refute service.disabled?
    assert_equal "enable_menu", sent.last[1]["name"]
  end

  private

  def build_page
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    [page, sent]
  end
end
