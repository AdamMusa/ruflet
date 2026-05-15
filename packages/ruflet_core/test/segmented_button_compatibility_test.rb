# frozen_string_literal: true

require_relative "test_helper"

class RufletSegmentedButtonCompatibilityTest < Minitest::Test
  def test_segmented_button_accepts_positional_segments_and_serializes_current_flet_props
    control = Ruflet.segmented_button(
      [
        Ruflet.segment("daily", label: "Daily", icon: "today"),
        Ruflet.segment("weekly", label: Ruflet.text("Weekly"), icon: Ruflet.icon("calendar_view_week"))
      ],
      selected: ["daily"],
      allow_empty_selection: false,
      allow_multiple_selection: false,
      direction: "horizontal",
      padding: { left: 4 },
      selected_icon: "check",
      show_selected_icon: true,
      style: { side: { color: "#ABCDEF" } },
      on_change: ->(_event) {}
    )

    patch = control.to_patch

    assert_equal "SegmentedButton", patch["_c"]
    assert_equal ["daily"], patch["selected"]
    assert_equal false, patch["allow_empty_selection"]
    assert_equal false, patch["allow_multiple_selection"]
    assert_equal "horizontal", patch["direction"]
    assert_equal({ "left" => 4 }, patch["padding"])
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("check"), patch["selected_icon"]
    assert_equal true, patch["show_selected_icon"]
    assert_equal({ "side" => { "color" => "#ABCDEF" } }, patch["style"])
    assert_equal true, patch["on_change"]

    first, second = patch["segments"]
    assert_equal "Segment", first["_c"]
    assert_equal "daily", first["value"]
    assert_equal "Daily", first["label"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("today"), first["icon"]
    assert_equal "Segment", second["_c"]
    assert_equal "weekly", second["value"]
    assert_equal "Text", second["label"]["_c"]
    assert_equal "Icon", second["icon"]["_c"]
  end

  def test_compact_alias_uses_same_control
    segments = [Ruflet.segment("daily", label: "Daily")]

    assert_equal "SegmentedButton", Ruflet.segmentedbutton(segments, selected: ["daily"]).to_patch["_c"]
  end

  def test_segment_requires_value_and_visible_label_or_icon_like_flet
    assert_raises(ArgumentError) { Ruflet.segment(label: "Daily") }
    assert_raises(ArgumentError) { Ruflet.segment("daily") }
    assert_raises(ArgumentError) { Ruflet.segment("daily", label: Ruflet.text("Hidden", visible: false)) }
  end

  def test_segmented_button_requires_segments_and_valid_selection_like_flet
    assert_raises(ArgumentError) { Ruflet.segmented_button([]) }

    segments = [
      Ruflet.segment("daily", label: "Daily"),
      Ruflet.segment("weekly", label: "Weekly")
    ]

    assert_raises(ArgumentError) { Ruflet.segmented_button(segments, selected: []) }
    assert_raises(ArgumentError) { Ruflet.segmented_button(segments, selected: ["daily", "weekly"]) }
    assert_raises(ArgumentError) { Ruflet.segmented_button(segments, selected: ["missing"]) }

    assert_equal [], Ruflet.segmented_button(segments, selected: [], allow_empty_selection: true).props["selected"]
    assert_equal ["daily", "weekly"], Ruflet.segmented_button(segments, selected: ["daily", "weekly"], allow_multiple_selection: true).props["selected"]
  end

  def test_segmented_button_change_event_updates_selected_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    control = Ruflet.segmented_button(
      [
        Ruflet.segment("daily", label: "Daily"),
        Ruflet.segment("weekly", label: "Weekly")
      ],
      selected: ["daily"],
      on_change: ->(event) { observed << [event.value, event.control.props["selected"]] }
    )
    page.add(control)

    page.dispatch_event(target: control.wire_id, name: "change", data: { "value" => ["weekly"] })

    assert_equal ["weekly"], control.props["selected"]
    assert_equal [[["weekly"], ["weekly"]]], observed
  end
end
