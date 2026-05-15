# frozen_string_literal: true

require_relative "test_helper"

class PageBatteryServiceTest < Minitest::Test
  def test_battery_methods_use_flet_method_names
    %w[get_battery_level get_battery_state is_in_battery_save_mode].each do |method_name|
      sent = []
      page = build_page(sent)

      call_id = page.public_send(method_name)
      refute_nil call_id

      invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == method_name }
      refute_nil invoke_payload
      assert_nil invoke_payload["args"]
    end
  end

  def test_legacy_battery_save_predicate_keeps_existing_ruby_api
    sent = []
    page = build_page(sent)

    call_id = page.battery_save_mode?
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "is_in_battery_save_mode" }
    refute_nil invoke_payload
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
