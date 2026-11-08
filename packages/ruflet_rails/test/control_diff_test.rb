# frozen_string_literal: true

require_relative "test_helper"

# An in-place re-render keeps the mounted controls and moves the fresh
# render's server-side callables onto them: handlers, and a form field's
# validator / on_saved / autovalidate_mode.
class RufletControlDiffTest < Minitest::Test
  ControlDiff = Ruflet::Rails::HtmlDsl::ControlDiff

  def test_rebinds_handlers_and_form_options_onto_the_mounted_controls
    calls = []
    old_handler = ->(_e) { calls << :old }
    new_handler = ->(_e) { calls << :new }
    old_validator = ->(_v) { "old" }
    new_validator = ->(_v) { "new" }
    saved = ->(_v) {}
    mounted = Ruflet.form([Ruflet.text_field(value: "a", validator: old_validator, on_change: old_handler)])
    fresh = Ruflet.form([Ruflet.text_field(value: "b", validator: new_validator, on_saved: saved,
                                           autovalidate_mode: "on_unfocus", on_change: new_handler)],
                        autovalidate_mode: "always")

    updates = ControlDiff.new(mounted, fresh).updates

    field = mounted.children.first
    assert_equal [[field, { value: "b" }]], updates
    assert_same new_validator, field.validator
    assert_same saved, field.on_saved
    assert_equal "on_unfocus", field.autovalidate_mode
    assert_equal "always", mounted.autovalidate_mode
    field.emit("change", nil)
    assert_equal [:new], calls
  end

  def test_a_validator_the_fresh_render_dropped_is_dropped
    mounted = Ruflet.text_field(value: "a", validator: ->(_v) { "x" })
    fresh = Ruflet.text_field(value: "a")

    assert_equal [], ControlDiff.new(mounted, fresh).updates
    assert_nil mounted.validator
  end
end
