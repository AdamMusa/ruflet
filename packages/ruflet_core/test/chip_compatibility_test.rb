# frozen_string_literal: true

require_relative "test_helper"

class RufletChipCompatibilityTest < Minitest::Test
  def test_chip_accepts_positional_label_and_serializes_current_flet_props
    chip = Ruflet.chip(
      "Explore topics",
      autofocus: true,
      bgcolor: "#ABCDEF",
      border_side: { color: "#111111", width: 1 },
      check_color: "#222222",
      clip_behavior: "antiAlias",
      color: { selected: "#333333" },
      delete_drawer_animation_style: { duration: 200 },
      delete_icon: Ruflet.icon("close"),
      delete_icon_color: "#444444",
      delete_icon_size_constraints: { min_width: 24 },
      delete_icon_tooltip: "Remove",
      disabled_color: "#555555",
      elevation: 2,
      elevation_on_click: 4,
      enable_animation_style: { duration: 100 },
      label_padding: { left: 8, right: 8 },
      label_text_style: { size: 14 },
      leading: Ruflet.icon("explore"),
      leading_drawer_animation_style: { duration: 150 },
      leading_size_constraints: { min_width: 24 },
      padding: 6,
      select_animation_style: { duration: 120 },
      selected: true,
      selected_color: "#666666",
      selected_shadow_color: "#777777",
      shadow_color: "#888888",
      shape: { border_radius: 8 },
      show_checkmark: true,
      visual_density: "compact",
      on_click: ->(_event) {},
      on_delete: ->(_event) {},
      on_focus: ->(_event) {},
      on_blur: ->(_event) {}
    )

    patch = chip.to_patch

    assert_equal "Chip", patch["_c"]
    assert_equal "Explore topics", patch["label"]
    assert_equal true, patch["autofocus"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal({ "color" => "#111111", "width" => 1 }, patch["border_side"])
    assert_equal "#222222", patch["check_color"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal({ "selected" => "#333333" }, patch["color"])
    assert_equal({ "duration" => 200 }, patch["delete_drawer_animation_style"])
    assert_equal "Icon", patch["delete_icon"]["_c"]
    assert_equal "#444444", patch["delete_icon_color"]
    assert_equal({ "min_width" => 24 }, patch["delete_icon_size_constraints"])
    assert_equal "Remove", patch["delete_icon_tooltip"]
    assert_equal "#555555", patch["disabled_color"]
    assert_equal 2, patch["elevation"]
    assert_equal 4, patch["elevation_on_click"]
    assert_equal({ "duration" => 100 }, patch["enable_animation_style"])
    assert_equal({ "left" => 8, "right" => 8 }, patch["label_padding"])
    assert_equal({ "size" => 14 }, patch["label_text_style"])
    assert_equal "Icon", patch["leading"]["_c"]
    assert_equal({ "duration" => 150 }, patch["leading_drawer_animation_style"])
    assert_equal({ "min_width" => 24 }, patch["leading_size_constraints"])
    assert_equal 6, patch["padding"]
    assert_equal({ "duration" => 120 }, patch["select_animation_style"])
    assert_equal true, patch["selected"]
    assert_equal "#666666", patch["selected_color"]
    assert_equal "#777777", patch["selected_shadow_color"]
    assert_equal "#888888", patch["shadow_color"]
    assert_equal({ "border_radius" => 8 }, patch["shape"])
    assert_equal true, patch["show_checkmark"]
    assert_equal "compact", patch["visual_density"]
    assert_equal true, patch["on_click"]
    assert_equal true, patch["on_delete"]
    assert_equal true, patch["on_focus"]
    assert_equal true, patch["on_blur"]
  end

  def test_chip_rejects_on_click_and_on_select_together_like_flet
    error = assert_raises(ArgumentError) do
      Ruflet.chip("Filter", on_click: ->(_event) {}, on_select: ->(_event) {})
    end

    assert_match(/on_click.*on_select|on_select.*on_click/, error.message)
  end

  def test_chip_rejects_negative_elevations_like_flet
    %i[elevation elevation_on_click].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.chip("Filter", prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end

  def test_chip_select_event_updates_selected_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    chip = Ruflet.chip("Filter", selected: false, on_select: ->(event) { observed << [event.value, event.control.props["selected"]] })
    page.add(chip)

    page.dispatch_event(target: chip.wire_id, name: "select", data: { "value" => true })

    assert_equal true, chip.props["selected"]
    assert_equal [[true, true]], observed
  end
end
