# frozen_string_literal: true

require_relative "test_helper"
require "ruflet_ui/ruflet/ui/controls/shared/ruflet_controls"

class RufletListSectionCompatibilityTest < Minitest::Test
  def test_list_section_serializes_wire_type_rows_and_section_props
    profile = Ruflet.list_tile(title: Ruflet.text("Profile"))
    alerts = Ruflet.list_tile(title: Ruflet.text("Notifications"))

    section = Ruflet.list_section(
      [profile, alerts],
      header: "Account",
      footer: "Signed in as ada@example.com",
      variant: "base",
      rows_bgcolor: "#FFFFFF",
      bgcolor: "#F2F2F7",
      separator_color: "#C6C6C8",
      has_leading: false,
      divider_margin: 20,
      additional_divider_margin: 4,
      top_margin: 12,
      border_radius: 14,
      clip_behavior: "antiAlias",
      margin: { left: 16, top: 0, right: 16, bottom: 8 }
    )
    patch = section.to_patch

    assert_equal "listsection", section.type
    assert_equal "ListSection", patch["_c"]
    assert_equal [profile, alerts], section.children
    refute section.props.key?("controls")
    assert_equal %w[ListTile ListTile], patch["controls"].map { |row| row["_c"] }
    assert_equal "Account", patch["header"]
    assert_equal "Signed in as ada@example.com", patch["footer"]
    assert_equal "base", patch["variant"]
    assert_equal "#ffffff", patch["rows_bgcolor"]
    assert_equal "#f2f2f7", patch["bgcolor"]
    assert_equal "#c6c6c8", patch["separator_color"]
    assert_equal false, patch["has_leading"]
    assert_equal 20, patch["divider_margin"]
    assert_equal 4, patch["additional_divider_margin"]
    assert_equal 12, patch["top_margin"]
    assert_equal 14, patch["border_radius"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal({ "left" => 16, "top" => 0, "right" => 16, "bottom" => 8 }, patch["margin"])
  end

  def test_list_section_defaults_to_the_inset_grouped_variant
    patch = Ruflet.list_section([Ruflet.text("Row")]).to_patch

    assert_equal "insetGrouped", patch["variant"]
    refute patch.key?("header")
    refute patch.key?("has_leading")
  end

  def test_list_section_header_and_footer_accept_controls
    section = Ruflet.list_section(
      header: Ruflet.text("Custom header"),
      footer: Ruflet.text("Custom footer")
    )
    patch = section.to_patch

    assert_equal "Text", patch["header"]["_c"]
    assert_equal "Custom header", patch["header"]["value"]
    assert_equal "Text", patch["footer"]["_c"]
    refute patch.key?("controls")
  end

  def test_list_section_collects_block_children_like_column
    section = Ruflet.list_section(header: "Settings") do
      list_tile(title: Ruflet.text("Wi-Fi"))
      list_tile(title: Ruflet.text("Bluetooth"))
    end

    assert_equal 2, section.children.length
    assert_equal %w[ListTile ListTile], section.to_patch["controls"].map { |row| row["_c"] }
  end

  def test_list_section_keeps_children_and_controls_keywords
    first = Ruflet.text("first")
    second = Ruflet.text("second")

    assert_equal [first], Ruflet.list_section(children: [first]).children
    assert_equal [second], Ruflet.list_section(controls: [second]).children
  end

  def test_compact_alias_uses_same_control
    section = Ruflet.listsection([Ruflet.text("Row")], header: "Alias")

    assert_equal "listsection", section.type
    assert_equal "ListSection", section.to_patch["_c"]
    assert_equal "Alias", section.to_patch["header"]
  end

  def test_dsl_app_builds_list_section
    app = Ruflet::DSL::App.new(host: "0.0.0.0", port: 8550)
    section = app.list_section([app.text(value: "Row")], header: "App")

    assert_equal "ListSection", section.to_patch["_c"]
    assert_equal 1, section.children.length
  end

  def test_list_section_accepts_common_layout_keywords_and_events
    section = Ruflet.list_section(
      [Ruflet.text("Row")],
      width: 320,
      expand: true,
      visible: true,
      on_size_change: ->(_event) {},
      on_animation_end: ->(_event) {}
    )
    patch = section.to_patch

    assert_equal 320, patch["width"]
    assert_equal true, patch["expand"]
    assert_equal true, patch["on_size_change"]
    assert section.has_handler?(:size_change)
    assert section.has_handler?(:animation_end)
  end

  def test_list_section_rejects_unknown_keywords
    assert_raises(ArgumentError) { Ruflet.list_section(not_a_real_prop: true) }
    assert_raises(ArgumentError) { Ruflet.list_section(on_click: ->(_event) {}) }
  end

  def test_list_section_is_registered_under_both_spellings
    map = Ruflet::UI::ControlFactory::CLASS_MAP

    assert_same Ruflet::UI::Controls::RufletComponents::ListSectionControl, map["list_section"]
    assert_same Ruflet::UI::Controls::RufletComponents::ListSectionControl, map["listsection"]
    assert_same map["list_section"], Ruflet::UI::Controls::Shared::RufletControls::CLASS_MAP["list_section"]
    assert_same map["listsection"], Ruflet::UI::Controls::Shared::RufletControls::CLASS_MAP["listsection"]
  end
end
