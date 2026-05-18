# frozen_string_literal: true

require_relative "test_helper"

class PageWakelockServiceTest < Minitest::Test
  def test_wakelock_with_props_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.wakelock(data: { "source" => "studio" }, key: "wakelock")

    assert_equal "wakelock", service.type
    assert_equal "Wakelock", service.to_patch["_c"]
    assert_equal({ "source" => "studio" }, service.props["data"])
    assert_equal "wakelock", service.props["key"]
    assert_same service, page.service(:wakelock)
  end

  def test_wakelock_methods_use_flet_payload_shape
    %w[enable disable is_enabled].each do |method_name|
      sent = []
      page = build_page(sent)

      call_id = page.wakelock.public_send(method_name)
      refute_nil call_id

      invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == method_name }
      refute_nil invoke_payload
      assert_nil invoke_payload["args"]
    end
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
