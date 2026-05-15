# frozen_string_literal: true

require_relative "test_helper"

class RufletTabsCompatibilityTest < Minitest::Test
  def test_tabs_serializes_current_flet_props_and_content
    control = Ruflet.tabs(
      length: 2,
      selected_index: 1,
      animation_duration: 150,
      content: Ruflet.column([
        Ruflet.tab_bar([
          Ruflet.tab(label: "Home", icon: "home"),
          Ruflet.tab(label: Ruflet.text("Settings"), icon: Ruflet.icon("settings"))
        ], divider_color: "#ABCDEF", divider_height: 1, indicator_thickness: 3, on_click: ->(_event) {}),
        Ruflet.tab_bar_view([
          Ruflet.text("Home body"),
          Ruflet.text("Settings body")
        ], viewport_fraction: 1.0)
      ]),
      on_change: ->(_event) {}
    )

    patch = control.to_patch

    assert_equal "Tabs", patch["_c"]
    assert_equal 2, patch["length"]
    assert_equal 1, patch["selected_index"]
    assert_equal 150, patch["animation_duration"]
    assert_equal true, patch["on_change"]
    assert_equal "Column", patch["content"]["_c"]

    tab_bar = patch["content"]["controls"].first
    assert_equal "TabBar", tab_bar["_c"]
    assert_equal "#abcdef", tab_bar["divider_color"]
    assert_equal 1, tab_bar["divider_height"]
    assert_equal 3, tab_bar["indicator_thickness"]
    assert_equal true, tab_bar["on_click"]
    assert_equal "Tab", tab_bar["tabs"].first["_c"]
    assert_equal "Home", tab_bar["tabs"].first["label"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("home"), tab_bar["tabs"].first["icon"]
    assert_equal "Text", tab_bar["tabs"].last["label"]["_c"]
    assert_equal "Icon", tab_bar["tabs"].last["icon"]["_c"]

    tab_view = patch["content"]["controls"].last
    assert_equal "TabBarView", tab_view["_c"]
    assert_equal 1.0, tab_view["viewport_fraction"]
    assert_equal %w[Text Text], tab_view["controls"].map { |child| child["_c"] }
  end

  def test_tabs_rejects_out_of_range_values_like_flet
    assert_raises(ArgumentError) { Ruflet.tabs(length: -1) }
    assert_raises(IndexError) { Ruflet.tabs(length: 2, selected_index: -3) }
    assert_raises(IndexError) { Ruflet.tabs(length: 2, selected_index: 2) }

    assert_equal(-1, Ruflet.tabs(length: 2, selected_index: -1).props["selected_index"])
  end

  def test_tab_requires_label_or_icon_like_flet
    error = assert_raises(ArgumentError) { Ruflet.tab }

    assert_match(/label|icon/, error.message)
  end

  def test_tab_rejects_height_below_flet_defaults
    assert_raises(ArgumentError) { Ruflet.tab(label: "Home", height: 45) }
    assert_raises(ArgumentError) { Ruflet.tab(label: "Home", icon: "home", height: 71) }
  end

  def test_tab_bar_rejects_negative_numeric_values_like_flet
    %i[divider_height indicator_thickness].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.tab_bar([Ruflet.tab(label: "Home")], prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end

  def test_tab_bar_view_rejects_invalid_viewport_fraction_like_flet
    assert_raises(ArgumentError) { Ruflet.tab_bar_view([Ruflet.text("Body")], viewport_fraction: 0) }
    assert_raises(ArgumentError) { Ruflet.tab_bar_view([Ruflet.text("Body")], viewport_fraction: -1) }
  end

  def test_tab_bar_view_uses_children_for_ruby_controls_collection
    first = Ruflet.text("One")
    second = Ruflet.text("Two")

    with_children = Ruflet.tab_bar_view(children: [first])
    with_controls_alias = Ruflet.tab_bar_view(controls: [second])

    assert_equal [first], with_children.children
    assert_equal [second], with_controls_alias.children
    refute with_children.props.key?("controls")
    refute with_controls_alias.props.key?("controls")
    assert_equal "Text", with_children.to_patch["controls"].first["_c"]
  end

  def test_tab_bar_view_defaults_match_flet
    control = Ruflet.tab_bar_view

    assert_equal [], control.children
    refute control.props.key?("controls")
    assert_equal "hardEdge", control.props["clip_behavior"]
    assert_equal 1.0, control.props["viewport_fraction"]
  end

  def test_tabs_change_event_updates_selected_index_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    control = Ruflet.tabs(
      length: 2,
      selected_index: 0,
      content: Ruflet.text("Body"),
      on_change: ->(event) { observed << [event.value, event.control.props["selected_index"]] }
    )
    page.add(control)

    page.dispatch_event(target: control.wire_id, name: "change", data: { "value" => 1 })

    assert_equal 1, control.props["selected_index"]
    assert_equal [[1, 1]], observed
  end
end
