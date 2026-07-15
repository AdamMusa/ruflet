# frozen_string_literal: true

require "minitest/autorun"
require "ruflet_ui"

class RufletSelectionAreaCompatibilityTest < Minitest::Test
  def test_selection_area_accepts_positional_content_and_serializes_current_flet_props
    area = Ruflet.selection_area(
      Ruflet.column([Ruflet.text("Selectable")]),
      disabled: false,
      tooltip: "Copy text",
      on_change: ->(_event) {}
    )

    patch = area.to_patch
    assert_equal "SelectionArea", patch["_c"]
    assert_equal "Column", patch["content"]["_c"]
    assert_equal false, patch["disabled"]
    assert_equal "Copy text", patch["tooltip"]
    assert_equal true, patch["on_change"]
  end

  def test_compact_alias_uses_same_control
    area = Ruflet.selectionarea(Ruflet.text("Selectable"))

    assert_equal "selectionarea", area.type
    assert_equal "SelectionArea", area.to_patch["_c"]
  end

  def test_selection_area_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.selection_area }
    assert_raises(ArgumentError) { Ruflet.selection_area(Ruflet.text("Hidden", visible: false)) }

    area = Ruflet.selection_area(Ruflet.text("Shown"))
    assert_equal "Shown", area.props["content"].props["value"]
  end

  def test_selection_area_change_event_exposes_selected_value_without_persisting_unknown_prop
    seen_value = nil
    area = Ruflet.selection_area(Ruflet.text("Selectable"), on_change: ->(event) { seen_value = event.value })
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(area)

    page.dispatch_event(target: area.wire_id, name: "change", data: { "value" => "Selectable" })

    assert_equal "Selectable", seen_value
    refute area.props.key?("value")
  end
end
