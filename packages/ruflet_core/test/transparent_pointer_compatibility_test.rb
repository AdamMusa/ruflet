# frozen_string_literal: true

require_relative "test_helper"

class RufletTransparentPointerCompatibilityTest < Minitest::Test
  def test_transparent_pointer_accepts_positional_content_and_serializes_current_flet_props
    pointer = Ruflet.transparent_pointer(
      Ruflet.container(content: Ruflet.text("Tap me")),
      expand: true,
      width: 200,
      height: 100
    )

    patch = pointer.to_patch

    assert_equal "TransparentPointer", patch["_c"]
    assert_equal "Container", patch["content"]["_c"]
    assert_equal true, patch["expand"]
    assert_equal 200, patch["width"]
    assert_equal 100, patch["height"]
  end

  def test_compact_alias_uses_same_control
    pointer = Ruflet.transparentpointer(Ruflet.text("Tap through"))

    assert_equal "transparentpointer", pointer.type
    assert_equal "TransparentPointer", pointer.to_patch["_c"]
  end

  def test_transparent_pointer_allows_nil_content_like_flet
    pointer = Ruflet.transparent_pointer

    assert_nil pointer.props["content"]
    assert_equal "TransparentPointer", pointer.to_patch["_c"]
  end
end
