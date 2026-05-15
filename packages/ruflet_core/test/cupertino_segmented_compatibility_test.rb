# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoSegmentedCompatibilityTest < Minitest::Test
  def test_cupertino_segmented_button_accepts_positional_children_and_serializes_current_flet_props
    children = [Ruflet.text("One"), Ruflet.text("Two")]

    control = Ruflet.cupertino_segmented_button(
      children,
      border_color: "#111111",
      click_color: "#222222",
      disabled_color: "#333333",
      disabled_text_color: "#444444",
      padding: { left: 8 },
      selected_color: "#555555",
      selected_index: 1,
      unselected_color: "#666666",
      on_change: ->(_event) {}
    )

    patch = control.to_patch

    assert_equal "CupertinoSegmentedButton", patch["_c"]
    assert_equal children, control.children
    refute control.props.key?("controls")
    assert_equal %w[One Two], patch["controls"].map { |child| child["value"] }
    assert_equal "#111111", patch["border_color"]
    assert_equal "#222222", patch["click_color"]
    assert_equal "#333333", patch["disabled_color"]
    assert_equal "#444444", patch["disabled_text_color"]
    assert_equal({ "left" => 8 }, patch["padding"])
    assert_equal "#555555", patch["selected_color"]
    assert_equal 1, patch["selected_index"]
    assert_equal "#666666", patch["unselected_color"]
    assert_equal true, patch["on_change"]
  end

  def test_cupertino_sliding_segmented_button_accepts_positional_children_and_serializes_current_flet_props
    children = [Ruflet.text("One"), Ruflet.text("Two")]

    control = Ruflet.cupertino_sliding_segmented_button(
      children,
      bgcolor: "#111111",
      padding: { left: 8 },
      proportional_width: true,
      selected_index: 1,
      thumb_color: "#222222",
      on_change: ->(_event) {}
    )

    patch = control.to_patch

    assert_equal "CupertinoSlidingSegmentedButton", patch["_c"]
    assert_equal children, control.children
    refute control.props.key?("controls")
    assert_equal %w[One Two], patch["controls"].map { |child| child["value"] }
    assert_equal "#111111", patch["bgcolor"]
    assert_equal({ "left" => 8 }, patch["padding"])
    assert_equal true, patch["proportional_width"]
    assert_equal 1, patch["selected_index"]
    assert_equal "#222222", patch["thumb_color"]
    assert_equal true, patch["on_change"]
  end

  def test_children_keyword_and_controls_alias_without_storing_controls_prop
    first = Ruflet.text("One")
    second = Ruflet.text("Two")

    segmented = Ruflet.cupertino_segmented_button(children: [first, second])
    segmented_alias = Ruflet.cupertino_segmented_button(controls: [first, second])
    sliding = Ruflet.cupertino_sliding_segmented_button(children: [first, second])
    sliding_alias = Ruflet.cupertino_sliding_segmented_button(controls: [first, second])

    assert_equal [first, second], segmented.children
    assert_equal [first, second], segmented_alias.children
    assert_equal [first, second], sliding.children
    assert_equal [first, second], sliding_alias.children
    refute segmented.props.key?("controls")
    refute segmented_alias.props.key?("controls")
    refute sliding.props.key?("controls")
    refute sliding_alias.props.key?("controls")
  end

  def test_compact_aliases_use_same_controls
    children = [Ruflet.text("One"), Ruflet.text("Two")]

    assert_equal "CupertinoSegmentedButton", Ruflet.cupertinosegmentedbutton(children).to_patch["_c"]
    assert_equal "CupertinoSlidingSegmentedButton", Ruflet.cupertinoslidingsegmentedbutton(children).to_patch["_c"]
  end

  def test_defaults_match_flet
    children = [Ruflet.text("One"), Ruflet.text("Two")]
    segmented = Ruflet.cupertino_segmented_button(children)
    sliding = Ruflet.cupertino_sliding_segmented_button(children)

    assert_equal 0, segmented.props["selected_index"]
    assert_equal 0, sliding.props["selected_index"]
    assert_equal false, sliding.props["proportional_width"]
  end

  def test_rejects_invalid_children_and_selected_index_like_flet
    child = Ruflet.text("One")
    children = [Ruflet.text("One"), Ruflet.text("Two")]

    assert_raises(ArgumentError) { Ruflet.cupertino_segmented_button([child]) }
    assert_raises(ArgumentError) { Ruflet.cupertino_sliding_segmented_button([child]) }
    assert_raises(IndexError) { Ruflet.cupertino_segmented_button(children, selected_index: -1) }
    assert_raises(IndexError) { Ruflet.cupertino_segmented_button(children, selected_index: 2) }
    assert_raises(IndexError) { Ruflet.cupertino_sliding_segmented_button(children, selected_index: -1) }
    assert_raises(IndexError) { Ruflet.cupertino_sliding_segmented_button(children, selected_index: 2) }
  end

  def test_change_event_updates_selected_index_before_handler
    observed = []
    control = Ruflet.cupertino_segmented_button(
      [Ruflet.text("One"), Ruflet.text("Two")],
      selected_index: 0,
      on_change: ->(event) { observed << [event.value, event.control.props["selected_index"]] }
    )
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(control)

    page.dispatch_event(target: control.wire_id, name: "change", data: { "value" => 1 })

    assert_equal 1, control.props["selected_index"]
    assert_equal [[1, 1]], observed
  end
end
