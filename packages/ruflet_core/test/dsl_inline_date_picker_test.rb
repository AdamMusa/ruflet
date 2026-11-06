# frozen_string_literal: true

require "json"
require_relative "test_helper"

# cupertino_date_picker and date_picker(inline: true) send the DatePicker wire
# type with inline: true, which the engine draws in place. DSL blocks
# therefore capture an inline picker like any other control, while a dialog
# DatePicker (no inline, or inline: false) stays a presented overlay.
class RufletDslInlineDatePickerTest < Minitest::Test
  def setup
    Ruflet::DSL._reset_pending_app!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  def test_builder_block_captures_an_inline_cupertino_date_picker
    column = Ruflet.column do
      cupertino_date_picker(on_change: ->(_event) {})
      text("below")
    end

    assert_equal %w[DatePicker Text], wire_types(column.children)
    assert_equal true, column.children.first.to_patch["inline"]
  end

  def test_prefixed_helpers_capture_an_inline_cupertino_date_picker
    column = Ruflet.column do
      Ruflet.text("label")
      Ruflet.cupertino_date_picker(on_change: ->(_event) {})
      Ruflet.text("after")
    end

    assert_equal %w[Text DatePicker Text], wire_types(column.children)
  end

  def test_bare_dsl_captures_an_inline_cupertino_date_picker
    list = column do
      cupertino_date_picker
      text("below")
    end

    assert_equal %w[DatePicker Text], wire_types(list.children)
  end

  def test_app_blocks_and_roots_capture_an_inline_cupertino_date_picker
    app = Ruflet::DSL.app
    column = app.column do
      cupertino_date_picker
      text("below")
    end
    root = app.cupertino_date_picker

    assert_equal %w[DatePicker Text], wire_types(column.children)
    assert_includes app.instance_variable_get(:@roots), root
  end

  def test_date_picker_inline_true_is_captured_and_the_dialog_variants_are_not
    column = Ruflet.column do
      date_picker(inline: true)
      date_picker
      date_picker(inline: false)
      cupertino_date_picker(inline: false)
      text("kept")
    end

    assert_equal %w[DatePicker Text], wire_types(column.children)
    assert_equal true, column.children.first.props["inline"]
  end

  def test_page_mount_sends_an_inline_date_picker_built_in_a_block
    page = new_page
    page.mount do
      column do
        cupertino_date_picker(on_change: ->(_event) {})
        text("below")
      end
    end

    assert_equal ["Column"], wire_types(page.controls)
    assert_equal %w[DatePicker Text], wire_types(page.controls.first.children)
    wire = JSON.generate(page.register_page_patch)
    assert_equal 1, wire.scan('"_c":"DatePicker"').length
  end

  def test_page_mount_lays_out_a_top_level_inline_date_picker
    page = new_page
    page.mount do
      cupertino_date_picker
      text("below")
    end

    assert_equal %w[DatePicker Text], wire_types(page.controls)
  end

  def test_inline_date_picker_built_in_a_block_receives_its_change_events
    page = new_page
    changes = []
    column = Ruflet.column do
      cupertino_date_picker(on_change: ->(event) { changes << event.data })
      text("below")
    end
    page.add(column)

    page.dispatch_event(target: column.children.first.wire_id, name: "change", data: "2026-11-06")

    assert_equal ["2026-11-06"], changes
  end

  def test_presented_control_exempts_only_an_inline_date_picker
    refute Ruflet::Page.presented_control?(Ruflet.cupertino_date_picker)
    refute Ruflet::Page.presented_control?(Ruflet.date_picker(inline: true))
    assert Ruflet::Page.presented_control?(Ruflet.date_picker)
    assert Ruflet::Page.presented_control?(Ruflet.date_picker(inline: false))
    assert Ruflet::Page.presented_control?(Ruflet.cupertino_date_picker(inline: false))
    assert Ruflet::Page.presented_control?(Ruflet.alert_dialog(title: Ruflet.text("x")))
  end

  private

  def new_page
    Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})
  end

  def wire_types(controls)
    controls.map { |control| control.to_patch["_c"] }
  end
end
