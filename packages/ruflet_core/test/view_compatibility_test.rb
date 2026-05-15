# frozen_string_literal: true

require_relative "test_helper"

class RufletViewCompatibilityTest < Minitest::Test
  def test_view_accepts_positional_children_and_serializes_current_flet_props
    first = Ruflet.text("One")
    second = Ruflet.text("Two")
    appbar = Ruflet.app_bar(title: Ruflet.text("Title"))

    view = Ruflet.view(
      [first, second],
      appbar: appbar,
      bgcolor: "#112233",
      can_pop: false,
      fullscreen_dialog: true,
      horizontal_alignment: "center",
      padding: { left: 8 },
      route: "/settings",
      spacing: 4,
      vertical_alignment: "end",
      on_confirm_pop: ->(_event) {}
    )

    patch = view.to_patch

    assert_equal "View", patch["_c"]
    assert_equal [first, second], view.children
    refute view.props.key?("controls")
    assert_equal ["One", "Two"], patch["controls"].map { |control| control["value"] }
    assert_equal "AppBar", patch["appbar"]["_c"]
    assert_equal "#112233", patch["bgcolor"]
    assert_equal false, patch["can_pop"]
    assert_equal true, patch["fullscreen_dialog"]
    assert_equal "center", patch["horizontal_alignment"]
    assert_equal({ "left" => 8 }, patch["padding"])
    assert_equal "/settings", patch["route"]
    assert_equal 4, patch["spacing"]
    assert_equal "end", patch["vertical_alignment"]
    assert_equal true, patch["on_confirm_pop"]
  end

  def test_view_accepts_children_keyword_and_controls_alias_without_storing_controls_prop
    first = Ruflet.text("One")
    second = Ruflet.text("Two")

    with_children = Ruflet.view(children: [first])
    with_controls_alias = Ruflet.view(controls: [second])

    assert_equal [first], with_children.children
    assert_equal [second], with_controls_alias.children
    refute with_children.props.key?("controls")
    refute with_controls_alias.props.key?("controls")
  end

  def test_view_defaults_match_flet
    view = Ruflet.view

    assert_equal [], view.children
    refute view.props.key?("controls")
    assert_equal true, view.props["can_pop"]
    assert_equal false, view.props["fullscreen_dialog"]
    assert_equal "start", view.props["horizontal_alignment"]
    assert_equal 10, view.props["padding"]
    assert_equal "/", view.props["route"]
    assert_equal 10, view.props["spacing"]
    assert_equal "start", view.props["vertical_alignment"]
  end

  def test_confirm_pop_event_dispatches
    observed = nil
    view = Ruflet.view(on_confirm_pop: ->(event) { observed = [event.name, event.target] })
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(view)

    page.dispatch_event(target: view.wire_id, name: "confirm_pop", data: nil)

    assert_equal ["confirm_pop", view.wire_id], observed
  end
end
