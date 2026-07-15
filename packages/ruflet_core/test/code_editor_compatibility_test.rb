# frozen_string_literal: true

require_relative "test_helper"

class RufletCodeEditorCompatibilityTest < Minitest::Test
  def test_code_editor_serializes_flet_props_and_events
    editor = Ruflet.code_editor(
      "puts 'hi'",
      language: "ruby",
      code_theme: "atom-one-dark",
      read_only: false,
      autocomplete: true,
      autocomplete_words: %w[def end class],
      autofocus: true,
      text_style: { size: 14 },
      padding: 8,
      on_change: ->(_event) {},
      on_focus: ->(_event) {},
      on_blur: ->(_event) {},
      on_selection_change: ->(_event) {}
    )

    patch = editor.to_patch

    assert_equal "CodeEditor", patch["_c"]
    assert_equal "puts 'hi'", patch["value"]
    assert_equal "ruby", patch["language"]
    assert_equal "atom-one-dark", patch["code_theme"]
    assert_equal false, patch["read_only"]
    assert_equal true, patch["autocomplete"]
    assert_equal %w[def end class], patch["autocomplete_words"]
    assert_equal true, patch["autofocus"]
    assert_equal({ "size" => 14 }, patch["text_style"])
    assert_equal 8, patch["padding"]
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_focus"]
    assert_equal true, patch["on_blur"]
    assert_equal true, patch["on_selection_change"]
    assert editor.has_handler?(:change)
    assert editor.has_handler?(:focus)
    assert editor.has_handler?(:blur)
    assert editor.has_handler?(:selection_change)
  end

  def test_code_editor_methods_invoke_flet_control_methods
    messages = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { messages << [action, payload] }
    )
    editor = Ruflet.code_editor("x = 1", language: "ruby")
    page.add(editor)
    messages.clear

    editor.focus
    editor.fold_imports
    editor.fold_comment_at_line_zero
    editor.fold_at(3)

    assert_equal %w[focus fold_imports fold_comment_at_line_zero fold_at],
                 messages.map { |_action, payload| payload["name"] }
    assert_nil messages[0].last["args"]
    assert_equal({ "line_number" => 3 }, messages[3].last["args"])
  end
end
