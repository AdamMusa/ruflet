# frozen_string_literal: true

require_relative "test_helper"

class RufletCarouselViewCompatibilityTest < Minitest::Test
  def test_carousel_view_accepts_positional_children_and_serializes_props
    banners = [Ruflet.text("One"), Ruflet.text("Two")]
    control = Ruflet.carousel_view(
      banners,
      height: 200,
      item_extent: 320,
      shrink_extent: 40,
      item_snapping: true,
      reverse: true,
      padding: 8,
      bgcolor: "#ABCDEF",
      elevation: 2,
      shape: { "_type" => "roundedRectangle", "radius" => 12 },
      item_clip_behavior: "hardEdge",
      overlay_color: { "pressed" => "#11223344" },
      enable_splash: false,
      initial_item: 1,
      on_item_click: ->(_e) {}
    )

    patch = control.to_patch

    assert_equal "CarouselView", patch["_c"]
    assert_equal banners, control.children
    refute control.props.key?("controls")
    assert_equal %w[One Two], patch["controls"].map { |child| child["value"] }
    assert_equal 200, patch["height"]
    assert_equal 320, patch["item_extent"]
    assert_equal 40, patch["shrink_extent"]
    assert_equal true, patch["item_snapping"]
    assert_equal true, patch["reverse"]
    assert_equal 8, patch["padding"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal 2, patch["elevation"]
    assert_equal({ "_type" => "roundedRectangle", "radius" => 12 }, patch["shape"])
    assert_equal "hardEdge", patch["item_clip_behavior"]
    assert_equal({ "pressed" => "#11223344" }, patch["overlay_color"])
    assert_equal false, patch["enable_splash"]
    assert_equal 1, patch["initial_item"]
    assert_equal true, patch["on_item_click"]
    assert control.has_handler?(:item_click)
  end

  def test_weighted_carousel_and_defaults
    control = Ruflet.carouselview(flex_weights: [3, 2, 1], consume_max_weight: false, controls: [Ruflet.text("A")])

    patch = control.to_patch
    assert_equal "carouselview", control.type
    assert_equal "CarouselView", patch["_c"]
    assert_equal [3, 2, 1], patch["flex_weights"]
    assert_equal false, patch["consume_max_weight"]
    assert_equal true, patch["horizontal"]
    refute patch.key?("item_extent")
    refute patch.key?("item_snapping")
  end

  def test_block_children_generic_control_and_dsl
    control = Ruflet.carousel_view(item_extent: 100) do
      text("First")
      text("Second")
    end

    assert_equal %w[First Second], control.to_patch["controls"].map { |child| child["value"] }
    assert_equal "CarouselView", Ruflet.control(:carousel_view, item_extent: 10).to_patch["_c"]
    assert_equal false, Ruflet.carousel_view(item_extent: 10, horizontal: false).to_patch["horizontal"]
    assert_respond_to Ruflet::DSL, :carousel_view
    assert_respond_to Ruflet::DSL, :carouselview
  end

  def test_item_click_event_reaches_handler
    page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_a, _p) {})
    observed = []
    control = Ruflet.carousel_view([Ruflet.text("A"), Ruflet.text("B")], item_extent: 100,
                                   on_item_click: ->(e) { observed << e.value })
    page.add(control)

    page.dispatch_event(target: control.wire_id, name: "item_click", data: 1)

    assert_equal [1], observed
  end

  def test_animate_to_item_invokes_the_carousel_method
    messages = []
    page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" },
                            sender: ->(action, payload) { messages << [action, payload] })
    control = Ruflet.carousel_view([Ruflet.text("A"), Ruflet.text("B"), Ruflet.text("C")], item_extent: 100)
    page.add(control)
    messages.clear

    control.animate_to_item(2)
    control.animate_to_item(0, duration: 500, curve: "easeInOut")

    assert_equal %w[animate_to_item animate_to_item], messages.map { |_action, payload| payload["name"] }
    assert_equal({ "index" => 2, "duration" => 300, "curve" => "ease" }, messages[0].last["args"])
    assert_equal({ "index" => 0, "duration" => 500, "curve" => "easeInOut" }, messages[1].last["args"])
    assert_equal control.wire_id, messages[0].last["control_id"]
  end

  def test_animate_to_item_without_a_page_is_a_no_op
    assert_nil Ruflet.carousel_view(item_extent: 10).animate_to_item(1)
  end

  def test_unknown_keywords_raise
    assert_raises(ArgumentError) { Ruflet.carousel_view(item_extent: 10, viewport_fraction: 0.8) }
    assert_raises(ArgumentError) { Ruflet.carousel_view(item_extent: 10, on_change: ->(_e) {}) }
  end
end
