# frozen_string_literal: true

require_relative "test_helper"

class RufletSemanticsCompatibilityTest < Minitest::Test
  def test_semantics_accepts_positional_content_and_serializes_current_flet_props
    control = Ruflet.semantics(
      Ruflet.icon("settings"),
      label: "Settings",
      hint_text: "Opens settings",
      button: true,
      checked: false,
      container: true,
      exclude_semantics: true,
      focusable: true,
      heading_level: 2,
      on_tap_hint_text: "Activate settings",
      on_long_press_hint_text: "Open context menu",
      on_tap: ->(_event) {}
    )

    patch = control.to_patch

    assert_equal "Semantics", patch["_c"]
    assert_equal "Icon", patch["content"]["_c"]
    assert_equal "Settings", patch["label"]
    assert_equal "Opens settings", patch["hint_text"]
    assert_equal true, patch["button"]
    assert_equal false, patch["checked"]
    assert_equal true, patch["container"]
    assert_equal true, patch["exclude_semantics"]
    assert_equal true, patch["focusable"]
    assert_equal 2, patch["heading_level"]
    assert_equal "Activate settings", patch["on_tap_hint_text"]
    assert_equal "Open context menu", patch["on_long_press_hint_text"]
    assert_equal true, patch["on_tap"]
  end

  def test_semantics_defaults_match_flet
    control = Ruflet.semantics

    assert_nil control.props["content"]
    assert_equal false, control.props["exclude_semantics"]
  end

  def test_semantics_tap_event_dispatches
    events = []
    control = Ruflet.semantics(Ruflet.text("Save"), on_tap: ->(event) { events << [event.name, event.control.type] })
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(control)

    page.dispatch_event(target: control.wire_id, name: "tap", data: {})

    assert_equal [["tap", "semantics"]], events
  end
end
