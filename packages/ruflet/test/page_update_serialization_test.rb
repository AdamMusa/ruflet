# frozen_string_literal: true

require_relative "test_helper"

class PageUpdateSerializationTest < Minitest::Test
  def test_update_serializes_embedded_controls
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    grid = Ruflet.grid_view
    page.add(grid)
    tile = Ruflet.container(content: Ruflet.text(value: "A"))

    page.update(grid, controls: [tile])

    payload = sent.last[1]
    controls_patch = payload["patch"].find { |op| op[2] == "controls" }
    refute_nil controls_patch

    controls_value = controls_patch[3]
    assert_instance_of Array, controls_value
    assert_instance_of Hash, controls_value.first
    assert_equal "Container", controls_value.first["_c"]
    refute_nil controls_value.first["_i"]
  end
end
