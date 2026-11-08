# frozen_string_literal: true

require_relative "test_helper"

# Flutter layout widgets with no Ruflet counterpart before: FractionallySizedBox,
# IntrinsicHeight, IntrinsicWidth, IgnorePointer, AbsorbPointer (boxes, laid
# out like any control) and SliverPadding (a sliver for CustomScrollView).
class RufletLayoutWidgetsCompatibilityTest < Minitest::Test
  def setup
    Ruflet::DSL._reset_pending_app!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  def test_fractionally_sized_box_serializes_its_factors_and_content
    patch = Ruflet.fractionally_sized_box(
      Ruflet.text("Half"), width_factor: 0.5, height_factor: 0.25, alignment: { x: -1, y: 0 }, margin: 4
    ).to_patch

    assert_equal "FractionallySizedBox", patch["_c"]
    assert_equal 0.5, patch["width_factor"]
    assert_equal 0.25, patch["height_factor"]
    assert_equal({ "x" => -1, "y" => 0 }, patch["alignment"])
    assert_equal 4, patch["margin"]
    assert_equal "Half", patch["content"]["value"]
  end

  def test_fractionally_sized_box_rejects_negative_or_non_numeric_factors
    assert_raises(ArgumentError) { Ruflet.fractionally_sized_box(width_factor: -0.1) }
    assert_raises(ArgumentError) { Ruflet.fractionally_sized_box(height_factor: "half") }
    assert_equal 0, Ruflet.fractionally_sized_box(width_factor: 0).to_patch["width_factor"]
  end

  def test_intrinsic_height_and_width_serialize
    row = Ruflet.row([Ruflet.text("a"), Ruflet.text("b")], vertical_alignment: "stretch")
    height = Ruflet.intrinsic_height(row).to_patch
    width = Ruflet.intrinsic_width(Ruflet.column([Ruflet.text("c")]), step_width: 8, step_height: 4).to_patch

    assert_equal "IntrinsicHeight", height["_c"]
    assert_equal "Row", height["content"]["_c"]
    assert_equal "IntrinsicWidth", width["_c"]
    assert_equal 8, width["step_width"]
    assert_equal 4, width["step_height"]
    assert_raises(ArgumentError) { Ruflet.intrinsic_width(step_width: -1) }
  end

  def test_pointer_blockers_default_to_on_and_keep_an_explicit_false
    assert_equal true, Ruflet.ignore_pointer(Ruflet.text("x")).to_patch["ignoring"]
    assert_equal false, Ruflet.ignore_pointer(Ruflet.text("x"), ignoring: false).to_patch["ignoring"]
    assert_equal true, Ruflet.absorb_pointer(Ruflet.text("x")).to_patch["absorbing"]
    assert_equal false, Ruflet.absorb_pointer(Ruflet.text("x"), absorbing: false).to_patch["absorbing"]
    assert_equal "IgnorePointer", Ruflet.ignore_pointer.to_patch["_c"]
    assert_equal "AbsorbPointer", Ruflet.absorb_pointer.to_patch["_c"]
  end

  def test_pointer_blocker_toggles_through_page_update
    page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_a, _p) {})
    blocker = Ruflet.absorb_pointer(Ruflet.button("Save"))
    page.add(blocker)

    page.update(blocker, absorbing: false)

    assert_equal false, blocker.props["absorbing"]
  end

  def test_sliver_padding_wraps_slivers_given_as_a_list_or_a_block
    listed = Ruflet.sliver_padding([Ruflet.sliver_list([Ruflet.text("A")])], padding: 16).to_patch
    app = Ruflet::DSL.app
    view = app.custom_scroll_view do
      sliver_padding(padding: { left: 8, right: 8 }) do
        sliver_list { text("One") }
        sliver_grid { text("Two") }
      end
    end
    padded = view.to_patch["controls"].first

    assert_equal "SliverPadding", listed["_c"]
    assert_equal 16, listed["padding"]
    assert_equal ["SliverList"], listed["slivers"].map { |sliver| sliver["_c"] }
    assert_equal "SliverPadding", padded["_c"]
    assert_equal %w[SliverList SliverGrid], padded["controls"].map { |sliver| sliver["_c"] }
    assert_equal ["SliverPadding"], view.to_patch["controls"].map { |sliver| sliver["_c"] }
  end

  def test_content_built_in_a_block_is_not_also_a_block_child
    column = Ruflet.column do
      fractionally_sized_box(text("half"), width_factor: 0.5)
      intrinsic_height(row([text("a"), text("b")]))
      ignore_pointer(text("ghost"))
      absorb_pointer(content: button("Locked"))
    end

    assert_equal %w[FractionallySizedBox IntrinsicHeight IgnorePointer AbsorbPointer],
                 column.children.map { |child| child.to_patch["_c"] }
  end

  def test_names_aliases_and_dsl_entry_points
    {
      "fractionally_sized_box" => "FractionallySizedBox",
      "fractionallysizedbox" => "FractionallySizedBox",
      "intrinsic_height" => "IntrinsicHeight",
      "intrinsicheight" => "IntrinsicHeight",
      "intrinsic_width" => "IntrinsicWidth",
      "intrinsicwidth" => "IntrinsicWidth",
      "ignore_pointer" => "IgnorePointer",
      "ignorepointer" => "IgnorePointer",
      "absorb_pointer" => "AbsorbPointer",
      "absorbpointer" => "AbsorbPointer",
      "sliver_padding" => "SliverPadding",
      "sliverpadding" => "SliverPadding"
    }.each do |name, wire|
      assert Ruflet::UI::ControlFactory.known_control?(name), name
      assert_equal wire, Ruflet::UI::ControlFactory.build(name).wire_type, name
      assert_equal wire, Ruflet.public_send(name).wire_type, "Ruflet.#{name}"
      assert_equal wire, Ruflet::DSL.app.public_send(name).wire_type, "DSL app #{name}"
    end
    assert_equal "IgnorePointer", ignore_pointer.wire_type
  end

  def test_unknown_keywords_raise
    assert_raises(ArgumentError) { Ruflet.ignore_pointer(absorbing: true) }
    assert_raises(ArgumentError) { Ruflet.sliver_padding(width: 10) }
    assert_raises(ArgumentError) { Ruflet.intrinsic_height(step_width: 2) }
  end
end
