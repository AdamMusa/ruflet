# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoPickerCompatibilityTest < Minitest::Test
  def test_cupertino_picker_accepts_positional_children_and_serializes_current_flet_props
    children = [Ruflet.text("Apple"), Ruflet.text("Mango")]

    picker = Ruflet.cupertino_picker(
      children,
      bgcolor: "#ABCDEF",
      default_selection_overlay_bgcolor: "#111111",
      diameter_ratio: 1.2,
      item_extent: 40,
      looping: true,
      magnification: 1.1,
      off_axis_fraction: 0.2,
      selected_index: 1,
      selection_overlay: Ruflet.container(bgcolor: "#222222"),
      squeeze: 1.3,
      use_magnifier: true,
      on_change: ->(_event) {}
    )

    patch = picker.to_patch

    assert_equal "CupertinoPicker", patch["_c"]
    assert_equal children, picker.children
    refute picker.props.key?("controls")
    assert_equal %w[Apple Mango], patch["controls"].map { |control| control["value"] }
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "#111111", patch["default_selection_overlay_bgcolor"]
    assert_equal 1.2, patch["diameter_ratio"]
    assert_equal 40, patch["item_extent"]
    assert_equal true, patch["looping"]
    assert_equal 1.1, patch["magnification"]
    assert_equal 0.2, patch["off_axis_fraction"]
    assert_equal 1, patch["selected_index"]
    assert_equal "Container", patch["selection_overlay"]["_c"]
    assert_equal 1.3, patch["squeeze"]
    assert_equal true, patch["use_magnifier"]
    assert_equal true, patch["on_change"]
  end

  def test_cupertino_picker_accepts_children_keyword_and_controls_alias_without_storing_controls_prop
    first = Ruflet.text("Apple")
    second = Ruflet.text("Mango")

    with_children = Ruflet.cupertino_picker(children: [first])
    with_controls_alias = Ruflet.cupertino_picker(controls: [second])

    assert_equal [first], with_children.children
    assert_equal [second], with_controls_alias.children
    refute with_children.props.key?("controls")
    refute with_controls_alias.props.key?("controls")
  end

  def test_compact_alias_uses_same_control
    picker = Ruflet.cupertinopicker([Ruflet.text("Apple")])

    assert_equal "cupertinopicker", picker.type
    assert_equal "CupertinoPicker", picker.to_patch["_c"]
  end

  def test_cupertino_picker_defaults_match_flet
    picker = Ruflet.cupertino_picker

    assert_equal [], picker.children
    refute picker.props.key?("controls")
    assert_equal 1.07, picker.props["diameter_ratio"]
    assert_equal 32.0, picker.props["item_extent"]
    assert_equal false, picker.props["looping"]
    assert_equal 1.0, picker.props["magnification"]
    assert_equal 0.0, picker.props["off_axis_fraction"]
    assert_equal 0, picker.props["selected_index"]
    assert_equal 1.45, picker.props["squeeze"]
    assert_equal false, picker.props["use_magnifier"]
  end

  def test_cupertino_picker_rejects_invalid_numeric_props_like_flet
    assert_raises(ArgumentError) { Ruflet.cupertino_picker(item_extent: 0) }
    assert_raises(ArgumentError) { Ruflet.cupertino_picker(item_extent: -1) }
    assert_raises(ArgumentError) { Ruflet.cupertino_picker(magnification: 0) }
    assert_raises(ArgumentError) { Ruflet.cupertino_picker(magnification: -1) }
    assert_raises(ArgumentError) { Ruflet.cupertino_picker(squeeze: 0) }
    assert_raises(ArgumentError) { Ruflet.cupertino_picker(squeeze: -1) }
    assert_raises(ArgumentError) { Ruflet.cupertino_picker(selected_index: -1) }
  end

  def test_cupertino_picker_change_event_updates_selected_index_before_handler
    observed = []
    picker = Ruflet.cupertino_picker(
      [Ruflet.text("Apple"), Ruflet.text("Mango")],
      selected_index: 0,
      on_change: ->(event) { observed << [event.value, event.control.props["selected_index"]] }
    )
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(picker)

    page.dispatch_event(target: picker.wire_id, name: "change", data: { "value" => 1 })

    assert_equal 1, picker.props["selected_index"]
    assert_equal [[1, 1]], observed
  end
end
