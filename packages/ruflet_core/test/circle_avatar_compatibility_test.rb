# frozen_string_literal: true

require_relative "test_helper"

class RufletCircleAvatarCompatibilityTest < Minitest::Test
  def test_circle_avatar_accepts_positional_content_and_serializes_current_flet_props
    avatar = Ruflet.circle_avatar(
      Ruflet.text("AB"),
      background_image_src: "fallback.png",
      bgcolor: "#ABCDEF",
      color: "#123456",
      foreground_image_src: "avatar.png",
      radius: 24,
      on_image_error: ->(_event) {}
    )

    patch = avatar.to_patch

    assert_equal "CircleAvatar", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "AB", patch["content"]["value"]
    assert_equal "fallback.png", patch["background_image_src"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "#123456", patch["color"]
    assert_equal "avatar.png", patch["foreground_image_src"]
    assert_equal 24, patch["radius"]
    assert_equal true, patch["on_image_error"]
  end

  def test_circleavatar_alias_uses_same_control
    assert_equal "CircleAvatar", Ruflet.circleavatar("AB").to_patch["_c"]
  end

  def test_circle_avatar_serializes_negative_radius_values_like_flet
    patch = Ruflet.circle_avatar(radius: -1, min_radius: -2, max_radius: -3).to_patch

    assert_equal(-1, patch["radius"])
    assert_equal(-2, patch["min_radius"])
    assert_equal(-3, patch["max_radius"])
  end

  def test_circle_avatar_serializes_radius_with_min_or_max_radius_like_flet
    min_patch = Ruflet.circle_avatar(radius: 20, min_radius: 10).to_patch
    max_patch = Ruflet.circle_avatar(radius: 20, max_radius: 30).to_patch

    assert_equal 20, min_patch["radius"]
    assert_equal 10, min_patch["min_radius"]
    assert_equal 20, max_patch["radius"]
    assert_equal 30, max_patch["max_radius"]
  end

  def test_circle_avatar_image_error_event_dispatches
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    events = []
    avatar = Ruflet.circle_avatar("AB", on_image_error: ->(event) { events << [event.name, event.control.type] })
    page.add(avatar)

    page.dispatch_event(target: avatar.wire_id, name: "image_error", data: nil)

    assert_equal [["image_error", "circleavatar"]], events
  end
end
