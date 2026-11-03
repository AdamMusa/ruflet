# frozen_string_literal: true

require_relative "test_helper"

# Flet 1.0.5's ScrollableControl.auto_scroll_animation: the animation
# auto_scroll uses to move to the end ({duration:, curve:}, a duration in
# milliseconds, or true). ResponsiveRow and ExpansionPanelList are
# ScrollableControls in Flet too, so they take the whole scroll surface.
class RufletAutoScrollAnimationCompatibilityTest < Minitest::Test
  ANIMATION = { duration: 250, curve: "easeOut" }.freeze
  WIRE_ANIMATION = { "duration" => 250, "curve" => "easeOut" }.freeze

  def scrollables
    {
      "Column" => ->(props) { Ruflet.column([Ruflet.text("a")], **props) },
      "Row" => ->(props) { Ruflet.row([Ruflet.text("a")], **props) },
      "ListView" => ->(props) { Ruflet.list_view([Ruflet.text("a")], **props) },
      "GridView" => ->(props) { Ruflet.grid_view([Ruflet.text("a")], **props) },
      "ReorderableListView" => ->(props) { Ruflet.reorderable_list_view([Ruflet.text("a")], **props) },
      "View" => ->(props) { Ruflet.view(route: "/", controls: [Ruflet.text("a")], **props) },
      "CustomScrollView" => ->(props) { Ruflet.custom_scroll_view(**props) },
      "ResponsiveRow" => ->(props) { Ruflet.responsive_row([Ruflet.text("a")], **props) },
      "ExpansionPanelList" => ->(props) { Ruflet.expansion_panel_list([Ruflet.expansion_panel], **props) }
    }
  end

  def test_every_scrollable_serializes_auto_scroll_animation
    scrollables.each do |wire, build|
      patch = build.call(auto_scroll: true, auto_scroll_animation: ANIMATION).to_patch

      assert_equal wire, patch["_c"]
      assert_equal true, patch["auto_scroll"], wire
      assert_equal WIRE_ANIMATION, patch["auto_scroll_animation"], wire
      refute build.call({}).to_patch.key?("auto_scroll_animation"), "#{wire} sends no default"
    end
  end

  def test_auto_scroll_animation_accepts_a_duration_or_true_like_flet
    assert_equal 0, Ruflet.column(auto_scroll_animation: 0).to_patch["auto_scroll_animation"]
    assert_equal true, Ruflet.list_view(auto_scroll_animation: true).to_patch["auto_scroll_animation"]
  end

  def test_responsive_row_and_expansion_panel_list_take_the_scroll_surface
    %w[ResponsiveRow ExpansionPanelList].each do |wire|
      control = scrollables.fetch(wire).call(
        scroll: "auto",
        auto_scroll: true,
        scroll_interval: 50,
        on_scroll: ->(_event) {}
      )
      patch = control.to_patch

      assert_equal "auto", patch["scroll"], wire
      assert_equal true, patch["auto_scroll"], wire
      assert_equal 50, patch["scroll_interval"], wire
      assert_equal true, patch["on_scroll"], wire
      assert_respond_to control, :scroll_to
    end
  end

  def test_responsive_row_and_expansion_panel_list_scroll_to_invokes_the_client
    sent = []
    page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(action, payload) { sent << [action, payload] })
    row = Ruflet.responsive_row([Ruflet.text("a")], scroll: "auto")
    panels = Ruflet.expansion_panel_list([Ruflet.expansion_panel], scroll: "auto")
    page.add(Ruflet.column([row, panels]))
    sent.clear

    row.scroll_to(offset: -1)
    panels.scroll_to(delta: 40, duration: 200)

    invokes = sent.map(&:last)
    assert_equal [row.wire_id, panels.wire_id], invokes.map { |payload| payload["control_id"] }
    assert_equal %w[scroll_to scroll_to], invokes.map { |payload| payload["name"] }
    assert_equal({ "delta" => 40, "duration" => 200 }, invokes.last["args"])
  end

  def test_page_auto_scroll_animation_goes_to_the_implicit_view
    sent = []
    page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(action, payload) { sent << [action, payload] })
    page.auto_scroll = true
    page.auto_scroll_animation = ANIMATION
    page.add(Ruflet.text("a"))

    view = sent.reverse_each.lazy.map { |_action, payload| payload.is_a?(Hash) && payload["patch"] }
                .select { |ops| ops.is_a?(Array) }
                .map { |ops| ops.find { |op| op.is_a?(Array) && op[2] == "views" } }
                .find(&:itself)[3].first

    assert_equal ANIMATION, page.auto_scroll_animation
    assert_equal true, view["auto_scroll"]
    assert_equal WIRE_ANIMATION, view["auto_scroll_animation"]
  end
end
