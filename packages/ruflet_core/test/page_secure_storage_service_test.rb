# frozen_string_literal: true

require_relative "test_helper"

class PageSecureStorageServiceTest < Minitest::Test
  def test_secure_storage_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.secure_storage(web_options: { db_name: "ruflet" }, on_change: ->(_event) {})

    assert_equal "securestorage", service.type
    assert_equal "SecureStorage", service.to_patch["_c"]
    assert_equal({ "db_name" => "ruflet" }, service.to_patch["web_options"])
    assert_equal true, service.props["on_change"]
    assert_same service, page.service(:secure_storage)
  end

  def test_secure_storage_methods_use_flet_payload_shape
    sent = []
    page = build_page(sent)
    service = page.secure_storage

    service.set("token", "secret", web: { db_name: "ruflet" })
    service.get("token")
    service.contains_key("token")
    service.get_all(android: { reset_on_error: true })
    service.remove("token")
    service.clear
    service.get_availability

    payloads = sent.map(&:last)
    assert_equal(
      { "key" => "token", "value" => "secret", "web" => { "db_name" => "ruflet" } },
      payloads.find { |payload| payload["name"] == "set" }["args"]
    )
    assert_equal({ "key" => "token" }, payloads.find { |payload| payload["name"] == "get" }["args"])
    assert_equal({ "key" => "token" }, payloads.find { |payload| payload["name"] == "contains_key" }["args"])
    assert_equal(
      { "android" => { "reset_on_error" => true } },
      payloads.find { |payload| payload["name"] == "get_all" }["args"]
    )
    assert_equal({ "key" => "token" }, payloads.find { |payload| payload["name"] == "remove" }["args"])
    assert_equal({}, payloads.find { |payload| payload["name"] == "clear" }["args"])
    assert_nil payloads.find { |payload| payload["name"] == "get_availability" }["args"]
  end

  def test_secure_storage_rejects_nil_values_like_flet
    service = build_page([]).secure_storage

    error = assert_raises(ArgumentError) { service.set("token", nil) }
    assert_match(/value/i, error.message)
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
