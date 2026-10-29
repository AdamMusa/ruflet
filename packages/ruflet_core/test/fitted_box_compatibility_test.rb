# frozen_string_literal: true

require_relative "test_helper"

class RufletFittedBoxCompatibilityTest < Minitest::Test
  def test_fitted_box_accepts_positional_content_and_serializes_props
    control = Ruflet.fitted_box(
      Ruflet.text("$1,299.00", size: 40),
      width: 120,
      height: 40,
      fit: "scaleDown",
      alignment: { x: -1, y: 0 },
      clip_behavior: "hardEdge",
      margin: 4
    )

    patch = control.to_patch

    assert_equal "FittedBox", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "$1,299.00", patch["content"]["value"]
    assert_equal "scaleDown", patch["fit"]
    assert_equal({ "x" => -1, "y" => 0 }, patch["alignment"])
    assert_equal "hardEdge", patch["clip_behavior"]
    assert_equal 120, patch["width"]
    assert_equal 40, patch["height"]
    assert_equal 4, patch["margin"]
  end

  def test_compact_alias_keyword_content_and_generic_control
    control = Ruflet.fittedbox(content: Ruflet.text("Alias"), fit: :cover)

    assert_equal "fittedbox", control.type
    assert_equal "FittedBox", control.to_patch["_c"]
    assert_equal "cover", control.to_patch["fit"]
    assert_equal "Text", control.to_patch["content"]["_c"]
    assert_equal "FittedBox", Ruflet.control(:fitted_box, content: Ruflet.text("x")).to_patch["_c"]
    assert_respond_to Ruflet::DSL, :fitted_box
    assert_respond_to Ruflet::DSL, :fittedbox
  end

  def test_renderer_defaults_are_not_sent
    patch = Ruflet.fitted_box(Ruflet.text("x")).to_patch

    refute patch.key?("fit")
    refute patch.key?("alignment")
    refute patch.key?("clip_behavior")
  end

  def test_layout_events_are_registered
    control = Ruflet.fitted_box(Ruflet.text("x"), on_size_change: ->(_e) {}, on_animation_end: ->(_e) {})

    assert control.has_handler?(:size_change)
    assert control.has_handler?(:animation_end)
  end

  def test_unknown_keyword_raises
    error = assert_raises(ArgumentError) { Ruflet.fitted_box(Ruflet.text("x"), scale_mode: "down") }

    assert_includes error.message, "scale_mode"
  end
end
