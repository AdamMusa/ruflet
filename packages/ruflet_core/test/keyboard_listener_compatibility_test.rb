# frozen_string_literal: true

require_relative "test_helper"

class RufletKeyboardListenerCompatibilityTest < Minitest::Test
  def test_keyboard_listener_serializes_flet_props_and_events
    keys = Ruflet.row(children: [Ruflet.text("A")])

    listener = Ruflet.keyboard_listener(
      keys,
      autofocus: true,
      include_semantics: false,
      tooltip: "Keyboard area",
      on_key_down: ->(_event) {},
      on_key_repeat: ->(_event) {},
      on_key_up: ->(_event) {}
    )

    patch = listener.to_patch

    assert_equal "KeyboardListener", patch["_c"]
    assert_equal "Row", patch["content"]["_c"]
    assert_equal true, patch["autofocus"]
    assert_equal false, patch["include_semantics"]
    assert_equal "Keyboard area", patch["tooltip"]
    assert_equal true, patch["on_key_down"]
    assert_equal true, patch["on_key_repeat"]
    assert_equal true, patch["on_key_up"]
    assert listener.has_handler?(:key_down)
    assert listener.has_handler?(:key_repeat)
    assert listener.has_handler?(:key_up)
  end

  def test_keyboardlistener_compact_alias_matches_flet_wire_name
    assert_equal "KeyboardListener", Ruflet.keyboardlistener.to_patch["_c"]
  end
end
