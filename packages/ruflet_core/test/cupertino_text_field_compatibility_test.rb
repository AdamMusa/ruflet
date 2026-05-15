# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoTextFieldCompatibilityTest < Minitest::Test
  def test_cupertino_text_field_accepts_positional_value_and_serializes_current_flet_props
    prefix = Ruflet.text("$")
    suffix = Ruflet.text("USD")
    field = Ruflet.cupertino_text_field(
      "42",
      placeholder_text: "Amount",
      placeholder_style: { color: "#AAAAAA" },
      clear_button_visibility_mode: "editing",
      clear_button_semantics_label: "Clear amount",
      prefix: prefix,
      suffix: suffix,
      prefix_visibility_mode: "always",
      suffix_visibility_mode: "not_editing",
      padding: { left: 8, top: 7, right: 8, bottom: 7 },
      bgcolor: "#FFFFFF",
      gradient: { colors: ["#FFFFFF", "#EEEEEE"] },
      image: { src: "background.png" },
      shadows: [{ color: "#111111", blur_radius: 2 }],
      blend_mode: "multiply",
      on_change: ->(_event) {},
      on_selection_change: ->(_event) {},
      on_submit: ->(_event) {},
      on_tap_outside: ->(_event) {}
    )

    patch = field.to_patch

    assert_equal "CupertinoTextField", patch["_c"]
    assert_equal "42", patch["value"]
    assert_equal "Amount", patch["placeholder_text"]
    assert_equal({ "color" => "#AAAAAA" }, patch["placeholder_style"])
    assert_equal "editing", patch["clear_button_visibility_mode"]
    assert_equal "Clear amount", patch["clear_button_semantics_label"]
    assert_equal "Text", patch["prefix"]["_c"]
    assert_equal "$", patch["prefix"]["value"]
    assert_equal "Text", patch["suffix"]["_c"]
    assert_equal "USD", patch["suffix"]["value"]
    assert_equal "always", patch["prefix_visibility_mode"]
    assert_equal "not_editing", patch["suffix_visibility_mode"]
    assert_equal({ "left" => 8, "top" => 7, "right" => 8, "bottom" => 7 }, patch["padding"])
    assert_equal "#ffffff", patch["bgcolor"]
    assert_equal({ "colors" => ["#FFFFFF", "#EEEEEE"] }, patch["gradient"])
    assert_equal({ "src" => "background.png" }, patch["image"])
    assert_equal [{ "color" => "#111111", "blur_radius" => 2 }], patch["shadows"]
    assert_equal "multiply", patch["blend_mode"]
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_selection_change"]
    assert_equal true, patch["on_submit"]
    assert_equal true, patch["on_tap_outside"]
  end

  def test_cupertino_text_field_defaults_match_flet
    field = Ruflet.cupertino_text_field

    assert_equal "Clear", field.props["clear_button_semantics_label"]
    assert_equal "never", field.props["clear_button_visibility_mode"]
    assert_equal({ "all" => 7 }, field.props["padding"])
    assert_equal "", field.props["placeholder_text"]
    assert_equal "always", field.props["prefix_visibility_mode"]
    assert_equal "always", field.props["suffix_visibility_mode"]
  end

  def test_cupertino_text_field_change_event_updates_value_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    field = Ruflet.cupertino_text_field("old", on_change: ->(event) { observed << [event.value, event.control.props["value"]] })
    page.add(field)

    page.dispatch_event(target: field.wire_id, name: "change", data: { "value" => "new" })

    assert_equal "new", field.props["value"]
    assert_equal [["new", "new"]], observed
  end

  def test_compact_alias_uses_same_control
    assert_equal "CupertinoTextField", Ruflet.cupertinotextfield.to_patch["_c"]
  end
end
