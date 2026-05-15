# frozen_string_literal: true

require_relative "test_helper"

class RufletContainerCompatibilityTest < Minitest::Test
  def test_container_serializes_current_flet_props_and_events_with_snake_case_keys
    clicked = []
    tapped = []
    content = Ruflet.text("inside")

    container = Ruflet.container(
      content: content,
      padding: { left: 1, top: 2, right: 3, bottom: 4 },
      alignment: { x: 0, y: 1 },
      bgcolor: "#ABCDEF",
      gradient: { type: "linear" },
      blend_mode: "modulate",
      border: { width: 1 },
      border_radius: 8,
      shape: "rectangle",
      clip_behavior: "anti_alias",
      ink: true,
      image: { src: "https://example.com/a.png" },
      ink_color: "#123456",
      animate: 300,
      blur: 10,
      shadow: { blur_radius: 4 },
      url: "https://flet.dev",
      theme: { color_scheme_seed: "#00FF00" },
      dark_theme: { color_scheme_seed: "#000000" },
      theme_mode: "dark",
      color_filter: { color: "#FFFFFF" },
      ignore_interactions: true,
      foreground_decoration: { border_radius: 4 },
      on_click: ->(_e) { clicked << :click },
      on_tap_down: ->(e) { tapped << [e.global_position.x, e.local_position.y] }
    )

    patch = container.to_patch

    assert_equal "Container", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal({ "left" => 1, "top" => 2, "right" => 3, "bottom" => 4 }, patch["padding"])
    assert_equal({ "x" => 0, "y" => 1 }, patch["alignment"])
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal({ "type" => "linear" }, patch["gradient"])
    assert_equal "modulate", patch["blend_mode"]
    assert_equal({ "width" => 1 }, patch["border"])
    assert_equal 8, patch["border_radius"]
    assert_equal "rectangle", patch["shape"]
    assert_equal "anti_alias", patch["clip_behavior"]
    assert_equal true, patch["ink"]
    assert_equal({ "src" => "https://example.com/a.png" }, patch["image"])
    assert_equal "#123456", patch["ink_color"]
    assert_equal 300, patch["animate"]
    assert_equal 10, patch["blur"]
    assert_equal({ "blur_radius" => 4 }, patch["shadow"])
    assert_equal "https://flet.dev", patch["url"]
    assert_equal({ "color_scheme_seed" => "#00FF00" }, patch["theme"])
    assert_equal({ "color_scheme_seed" => "#000000" }, patch["dark_theme"])
    assert_equal "dark", patch["theme_mode"]
    assert_equal({ "color" => "#FFFFFF" }, patch["color_filter"])
    assert_equal true, patch["ignore_interactions"]
    assert_equal({ "border_radius" => 4 }, patch["foreground_decoration"])
    assert_equal true, patch["on_click"]
    assert_equal true, patch["on_tap_down"]

    container.emit("click", Ruflet::Event.new(name: "click", target: "1", raw_data: nil, page: nil, control: container))
    container.emit("tap_down", Ruflet::Event.new(name: "tap_down", target: "1", raw_data: { "gx" => 10, "gy" => 20, "lx" => 3, "ly" => 4 }, page: nil, control: container))

    assert_equal [:click], clicked
    assert_equal [[10, 4]], tapped
  end
end
