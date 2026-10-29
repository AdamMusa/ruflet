# frozen_string_literal: true

require_relative "test_helper"
require "ruflet_ui/ruflet/ui/controls/shared/ruflet_controls"

class RufletFormRowCompatibilityTest < Minitest::Test
  def test_form_row_serializes_wire_type_content_and_labels
    field = Ruflet.text_field(border: "none", text_align: "end")

    row = Ruflet.form_row(
      field,
      prefix: "Name",
      helper: "As it appears on your card",
      error: "Required",
      padding: { left: 20, top: 6, right: 6, bottom: 6 }
    )
    patch = row.to_patch

    assert_equal "formrow", row.type
    assert_equal "FormRow", patch["_c"]
    assert_equal "TextField", patch["content"]["_c"]
    assert_equal "Name", patch["prefix"]
    assert_equal "As it appears on your card", patch["helper"]
    assert_equal "Required", patch["error"]
    assert_equal({ "left" => 20, "top" => 6, "right" => 6, "bottom" => 6 }, patch["padding"])
    refute patch.key?("controls")
  end

  def test_form_row_labels_accept_controls
    patch = Ruflet.form_row(
      Ruflet.switch(value: true),
      prefix: Ruflet.text("Airplane mode"),
      helper: Ruflet.text("Helper"),
      error: Ruflet.text("Error")
    ).to_patch

    assert_equal "Switch", patch["content"]["_c"]
    assert_equal "Airplane mode", patch["prefix"]["value"]
    assert_equal "Text", patch["helper"]["_c"]
    assert_equal "Text", patch["error"]["_c"]
    refute patch.key?("padding")
  end

  def test_form_row_accepts_content_keyword
    patch = Ruflet.form_row(content: Ruflet.text("Value"), prefix: "Label").to_patch

    assert_equal "Value", patch["content"]["value"]
  end

  def test_form_row_requires_content
    error = assert_raises(ArgumentError) { Ruflet.form_row(prefix: "Name") }

    assert_equal "form_row requires content", error.message
  end

  def test_compact_alias_uses_same_control
    row = Ruflet.formrow(Ruflet.text("Value"), prefix: "Alias")

    assert_equal "formrow", row.type
    assert_equal "FormRow", row.to_patch["_c"]
    assert_equal "Alias", row.to_patch["prefix"]
  end

  def test_dsl_app_builds_form_row
    app = Ruflet::DSL::App.new(host: "0.0.0.0", port: 8550)
    row = app.form_row(app.text(value: "Value"), prefix: "App")

    assert_equal "FormRow", row.to_patch["_c"]
    assert_equal "App", row.to_patch["prefix"]
  end

  def test_form_row_serializes_as_a_child_row
    section = Ruflet.column([Ruflet.form_row(Ruflet.text_field(border: "none"), prefix: "Name")])

    assert_equal "FormRow", section.to_patch["controls"].first["_c"]
  end

  def test_form_row_accepts_common_layout_keywords_and_events
    row = Ruflet.form_row(
      Ruflet.text("Value"),
      width: 320,
      visible: true,
      expand: true,
      on_size_change: ->(_event) {},
      on_animation_end: ->(_event) {}
    )
    patch = row.to_patch

    assert_equal 320, patch["width"]
    assert_equal true, patch["expand"]
    assert_equal true, patch["on_size_change"]
    assert row.has_handler?(:size_change)
    assert row.has_handler?(:animation_end)
  end

  def test_form_row_rejects_unknown_keywords
    assert_raises(ArgumentError) { Ruflet.form_row(Ruflet.text("Value"), label: "Name") }
    assert_raises(ArgumentError) { Ruflet.form_row(Ruflet.text("Value"), on_click: ->(_event) {}) }
  end

  def test_form_row_is_registered_under_both_spellings
    map = Ruflet::UI::ControlFactory::CLASS_MAP
    shared = Ruflet::UI::Controls::Shared::RufletControls::CLASS_MAP

    assert_same Ruflet::UI::Controls::RufletComponents::FormRowControl, map["form_row"]
    assert_same Ruflet::UI::Controls::RufletComponents::FormRowControl, map["formrow"]
    assert_same map["form_row"], shared["form_row"]
    assert_same map["formrow"], shared["formrow"]
  end
end
