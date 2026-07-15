# frozen_string_literal: true

require_relative "test_helper"

class RufletPageViewCompatibilityTest < Minitest::Test
  def test_page_view_accepts_positional_children_and_serializes_current_flet_props
    first = Ruflet.text("One")
    second = Ruflet.text("Two")

    page_view = Ruflet.page_view(
      [first, second],
      clip_behavior: "antiAlias",
      horizontal: false,
      implicit_scrolling: true,
      keep_page: false,
      pad_ends: false,
      reverse: true,
      selected_index: 1,
      snap: false,
      viewport_fraction: 0.8,
      on_change: ->(_event) {}
    )

    patch = page_view.to_patch

    assert_equal "PageView", patch["_c"]
    assert_equal [first, second], page_view.children
    refute page_view.props.key?("controls")
    assert_equal ["One", "Two"], patch["controls"].map { |control| control["value"] }
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal false, patch["horizontal"]
    assert_equal true, patch["implicit_scrolling"]
    assert_equal false, patch["keep_page"]
    assert_equal false, patch["pad_ends"]
    assert_equal true, patch["reverse"]
    assert_equal 1, patch["selected_index"]
    assert_equal false, patch["snap"]
    assert_equal 0.8, patch["viewport_fraction"]
    assert_equal true, patch["on_change"]
  end

  def test_page_view_accepts_children_keyword_and_controls_alias_without_storing_controls_prop
    first = Ruflet.text("One")
    second = Ruflet.text("Two")

    with_children = Ruflet.page_view(children: [first])
    with_controls_alias = Ruflet.page_view(controls: [second])

    assert_equal [first], with_children.children
    assert_equal [second], with_controls_alias.children
    refute with_children.props.key?("controls")
    refute with_controls_alias.props.key?("controls")
  end

  def test_compact_alias_uses_same_control
    page_view = Ruflet.pageview([Ruflet.text("One")])

    assert_equal "pageview", page_view.type
    assert_equal "PageView", page_view.to_patch["_c"]
  end

  def test_page_view_defaults_match_flet
    page_view = Ruflet.page_view

    assert_equal [], page_view.children
    refute page_view.props.key?("controls")
    assert_equal "hardEdge", page_view.props["clip_behavior"]
    assert_equal true, page_view.props["horizontal"]
    assert_equal false, page_view.props["implicit_scrolling"]
    assert_equal true, page_view.props["keep_page"]
    assert_equal true, page_view.props["pad_ends"]
    assert_equal false, page_view.props["reverse"]
    assert_equal 0, page_view.props["selected_index"]
    assert_equal true, page_view.props["snap"]
    assert_equal 1.0, page_view.props["viewport_fraction"]
  end

  def test_page_view_rejects_invalid_numeric_props_like_flet
    assert_raises(ArgumentError) { Ruflet.page_view(selected_index: -1) }
    assert_raises(ArgumentError) { Ruflet.page_view(viewport_fraction: 0) }
    assert_raises(ArgumentError) { Ruflet.page_view(viewport_fraction: -1) }
  end

  def test_page_view_change_event_updates_selected_index_before_handler
    observed = []
    page_view = Ruflet.page_view(
      [Ruflet.text("One"), Ruflet.text("Two")],
      selected_index: 0,
      on_change: ->(event) { observed << [event.value, event.control.props["selected_index"]] }
    )
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(page_view)

    page.dispatch_event(target: page_view.wire_id, name: "change", data: { "value" => 1 })

    assert_equal 1, page_view.props["selected_index"]
    assert_equal [[1, 1]], observed
  end
end
