# frozen_string_literal: true

require_relative "test_helper"

class RufletMergeSemanticsCompatibilityTest < Minitest::Test
  def test_merge_semantics_accepts_positional_content_and_serializes_current_flet_props
    control = Ruflet.merge_semantics(
      Ruflet.row([Ruflet.icon("check"), Ruflet.text("Enabled")]),
      tooltip: "Merged",
      visible: true
    )

    patch = control.to_patch

    assert_equal "MergeSemantics", patch["_c"]
    assert_equal "Row", patch["content"]["_c"]
    assert_equal "Merged", patch["tooltip"]
    assert_equal true, patch["visible"]
  end

  def test_compact_alias_uses_same_control
    control = Ruflet.mergesemantics(Ruflet.text("Enabled"))

    assert_equal "mergesemantics", control.type
    assert_equal "MergeSemantics", control.to_patch["_c"]
  end

  def test_merge_semantics_allows_nil_content_like_flet
    control = Ruflet.merge_semantics

    assert_nil control.props["content"]
    assert_equal "MergeSemantics", control.to_patch["_c"]
  end
end
