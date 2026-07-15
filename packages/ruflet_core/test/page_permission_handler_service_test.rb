# frozen_string_literal: true

require_relative "test_helper"

class PagePermissionHandlerServiceTest < Minitest::Test
  def test_permission_handler_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.permission_handler(data: { "source" => "studio" }, key: "permissions")

    assert_equal "permissionhandler", service.type
    assert_equal "PermissionHandler", service.to_patch["_c"]
    assert_equal({ "source" => "studio" }, service.props["data"])
    assert_equal "permissions", service.props["key"]
    assert_same service, page.service(:permission_handler)
  end

  def test_permission_handler_methods_use_flet_payload_shape
    sent = []
    page = build_page(sent)
    service = page.permission_handler

    service.get_status(:microphone)
    service.request(:camera)
    service.open_app_settings

    payloads = sent.map(&:last)
    assert_equal({ "permission" => "microphone" }, payloads.find { |payload| payload["name"] == "get_status" }["args"])
    assert_equal({ "permission" => "camera" }, payloads.find { |payload| payload["name"] == "request" }["args"])
    assert_nil payloads.find { |payload| payload["name"] == "open_app_settings" }["args"]
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
