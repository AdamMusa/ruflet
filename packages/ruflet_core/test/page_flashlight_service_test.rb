# frozen_string_literal: true

require_relative "test_helper"

class PageFlashlightServiceTest < Minitest::Test
  def test_flashlight_methods_use_flet_payload_shape
    %w[on off is_available].each do |method_name|
      sent = []
      page = build_page(sent)

      call_id = page.flashlight.public_send(method_name)
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
