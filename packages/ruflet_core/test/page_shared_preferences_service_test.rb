# frozen_string_literal: true

require_relative "test_helper"

class PageSharedPreferencesServiceTest < Minitest::Test
  def test_shared_preferences_with_props_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.shared_preferences(data: { "source" => "studio" }, key: "prefs")

    assert_equal "sharedpreferences", service.type
    assert_equal "SharedPreferences", service.to_patch["_c"]
    assert_equal({ "source" => "studio" }, service.props["data"])
    assert_equal "prefs", service.props["key"]
    assert_same service, page.service(:shared_preferences)
  end

  def test_shared_preferences_set_uses_flet_payload_shape
    sent = []
    page = build_page(sent)

    call_id = page.shared_preferences.set("theme", "dark")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "set" }
    refute_nil invoke_payload
    assert_equal({ "key" => "theme", "value" => "dark" }, invoke_payload["args"])
  end

  def test_shared_preferences_get_uses_flet_payload_shape
    sent = []
    page = build_page(sent)

    call_id = page.shared_preferences.get("theme")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "get" }
    refute_nil invoke_payload
    assert_equal({ "key" => "theme" }, invoke_payload["args"])
  end

  def test_shared_preferences_contains_key_and_get_keys_use_flet_payload_shape
    sent = []
    page = build_page(sent)

    page.shared_preferences.contains_key("theme")
    page.shared_preferences.get_keys("theme.")

    contains_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "contains_key" }
    keys_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "get_keys" }

    refute_nil contains_payload
    refute_nil keys_payload
    assert_equal({ "key" => "theme" }, contains_payload["args"])
    assert_equal({ "key_prefix" => "theme." }, keys_payload["args"])
  end

  def test_shared_preferences_remove_and_clear_use_flet_payload_shape
    sent = []
    page = build_page(sent)

    page.shared_preferences.remove("theme")
    page.shared_preferences.clear

    remove_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "remove" }
    clear_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "clear" }

    refute_nil remove_payload
    refute_nil clear_payload
    assert_equal({ "key" => "theme" }, remove_payload["args"])
    assert_nil clear_payload["args"]
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
