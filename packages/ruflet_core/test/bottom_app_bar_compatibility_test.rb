# frozen_string_literal: true

require_relative "test_helper"

class RufletBottomAppBarCompatibilityTest < Minitest::Test
  def test_bottom_app_bar_accepts_positional_content_and_serializes_current_flet_props
    bar = Ruflet.bottom_app_bar(
      Ruflet.row([Ruflet.icon_button("menu"), Ruflet.icon_button("search")]),
      bgcolor: "#336699",
      border_radius: { top_left: 12 },
      clip_behavior: "antiAlias",
      elevation: 3,
      height: 80,
      notch_margin: 4.0,
      padding: { left: 16, right: 16 },
      shadow_color: "#112233",
      shape: "circularRectangle"
    )

    patch = bar.to_patch

    assert_equal "BottomAppBar", patch["_c"]
    assert_equal "Row", patch["content"]["_c"]
    assert_equal "#336699", patch["bgcolor"]
    assert_equal({ "top_left" => 12 }, patch["border_radius"])
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal 3, patch["elevation"]
    assert_equal 80, patch["height"]
    assert_equal 4.0, patch["notch_margin"]
    assert_equal({ "left" => 16, "right" => 16 }, patch["padding"])
    assert_equal "#112233", patch["shadow_color"]
    assert_equal "circularRectangle", patch["shape"]
  end

  def test_compact_alias_uses_same_control
    bar = Ruflet.bottomappbar(Ruflet.text("Actions"))

    assert_equal "bottomappbar", bar.type
    assert_equal "BottomAppBar", bar.to_patch["_c"]
  end

  def test_bottom_app_bar_allows_nil_content_like_flet
    bar = Ruflet.bottom_app_bar(bgcolor: "#000000")

    assert_nil bar.props["content"]
    assert_equal "#000000", bar.props["bgcolor"]
  end

  def test_bottom_app_bar_rejects_negative_elevation_like_flet
    assert_raises(ArgumentError) { Ruflet.bottom_app_bar(elevation: -1) }
  end

  def test_page_add_serializes_bottom_app_bar_as_view_slot
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.add(Ruflet.text("Body"), bottom_appbar: Ruflet.bottom_app_bar(Ruflet.text("Actions")))

    views_patch = sent.last[1]["patch"].find { |op| op[2] == "views" }
    view = views_patch[3].first
    assert_equal "BottomAppBar", view["bottom_appbar"]["_c"]
    assert_equal "Text", view["bottom_appbar"]["content"]["_c"]
  end

  def test_page_bottom_appbar_setter_serializes_view_slot_on_update
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    page.add(Ruflet.text("Body"))

    page.bottom_appbar = Ruflet.bottom_app_bar(Ruflet.text("Actions"))
    page.update

    views_patch = sent.last[1]["patch"].find { |op| op[2] == "views" }
    view = views_patch[3].first
    assert_equal "BottomAppBar", view["bottom_appbar"]["_c"]
  end
end
