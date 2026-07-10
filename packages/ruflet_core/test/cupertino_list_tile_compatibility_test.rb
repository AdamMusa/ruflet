# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoListTileCompatibilityTest < Minitest::Test
  def test_cupertino_list_tile_serializes_current_flet_props
    tile = Ruflet.cupertino_list_tile(
      title: Ruflet.text("Notifications"),
      subtitle: "Enabled",
      additional_info: Ruflet.text("Now"),
      bgcolor: "#ABCDEF",
      bgcolor_activated: "#111111",
      leading: "notifications",
      leading_size: 32,
      leading_to_title: 14,
      notched: true,
      padding: { left: 8 },
      toggle_inputs: true,
      trailing: Ruflet.icon("chevron_right"),
      url: "https://flet.dev",
      on_click: ->(_event) {}
    )

    patch = tile.to_patch

    assert_equal "CupertinoListTile", patch["_c"]
    assert_equal "Text", patch["title"]["_c"]
    assert_equal "Enabled", patch["subtitle"]
    assert_equal "Text", patch["additional_info"]["_c"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "#111111", patch["bgcolor_activated"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("notifications"), patch["leading"]
    assert_equal 32, patch["leading_size"]
    assert_equal 14, patch["leading_to_title"]
    assert_equal true, patch["notched"]
    assert_equal({ "left" => 8 }, patch["padding"])
    assert_equal true, patch["toggle_inputs"]
    assert_equal "Icon", patch["trailing"]["_c"]
    assert_equal "https://flet.dev", patch["url"]
    assert_equal true, patch["on_click"]
  end

  def test_compact_alias_uses_same_control
    assert_equal "CupertinoListTile", Ruflet.cupertinolisttile(title: "Title").to_patch["_c"]
  end

  def test_cupertino_list_tile_defaults_match_flet
    plain = Ruflet.cupertino_list_tile(title: "Plain")
    notched = Ruflet.cupertino_list_tile(title: "Notched", notched: true)

    assert_equal false, plain.props["notched"]
    assert_equal 28.0, plain.props["leading_size"]
    assert_equal 16.0, plain.props["leading_to_title"]
    assert_equal false, plain.props["toggle_inputs"]
    assert_equal 30.0, notched.props["leading_size"]
    assert_equal 12.0, notched.props["leading_to_title"]
  end

  def test_cupertino_list_tile_requires_title_and_serializes_hidden_title_like_flet
    assert_raises(ArgumentError) { Ruflet.cupertino_list_tile }
    hidden = Ruflet.cupertino_list_tile(title: Ruflet.container(visible: false)).to_patch

    assert_equal false, hidden["title"]["visible"]
  end

  def test_cupertino_list_tile_serializes_negative_numeric_values_like_flet
    patch = Ruflet.cupertino_list_tile(title: "Title", leading_size: -1, leading_to_title: -2).to_patch

    assert_equal(-1, patch["leading_size"])
    assert_equal(-2, patch["leading_to_title"])
  end

  def test_cupertino_list_tile_click_event_dispatches
    observed = []
    tile = Ruflet.cupertino_list_tile(title: "Title", on_click: ->(event) { observed << [event.name, event.control.props["title"]] })
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(tile)

    page.dispatch_event(target: tile.wire_id, name: "click", data: nil)

    assert_equal [["click", "Title"]], observed
  end
end
