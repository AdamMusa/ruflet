# frozen_string_literal: true

require_relative "test_helper"

class PageScreenBrightnessServiceTest < Minitest::Test
  def test_screen_brightness_no_arg_methods_use_flet_payload_shape
    methods = %w[
      can_change_system_screen_brightness
      get_application_screen_brightness
      get_system_screen_brightness
      is_animate
      is_auto_reset
      reset_application_screen_brightness
    ]

    methods.each do |method_name|
      sent = []
      page = build_page(sent)

      call_id = page.screen_brightness.public_send(method_name)
      refute_nil call_id

      invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == method_name }
      refute_nil invoke_payload
      assert_nil invoke_payload["args"]
    end
  end

  def test_screen_brightness_setters_use_flet_payload_shape
    cases = {
      set_animate: [false, { "value" => false }],
      set_auto_reset: [true, { "value" => true }],
      set_application_screen_brightness: [0.75, { "value" => 0.75 }],
      set_system_screen_brightness: [0.25, { "value" => 0.25 }]
    }

    cases.each do |method_name, (value, expected_args)|
      sent = []
      page = build_page(sent)

      call_id = page.screen_brightness.public_send(method_name, value)
      refute_nil call_id

      invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == method_name.to_s }
      refute_nil invoke_payload
      assert_equal expected_args, invoke_payload["args"]
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
