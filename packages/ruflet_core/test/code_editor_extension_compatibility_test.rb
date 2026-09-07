# frozen_string_literal: true

require_relative "test_helper"

class CodeEditorExtensionCompatibilityTest < Minitest::Test
  def test_code_editor_accepts_current_flet_properties_and_events
    editor = Ruflet.code_editor(
      "puts :ok",
      language: :ruby,
      selection: { base_offset: 0, extent_offset: 4 },
      gutter_style: { show_line_numbers: true },
      on_selection_change: ->(_event) {}
    )

    patch = editor.to_patch
    assert_equal "CodeEditor", patch["_c"]
    assert_equal "ruby", patch["language"]
    assert_equal({ "base_offset" => 0, "extent_offset" => 4 }, patch["selection"])
    assert editor.has_handler?(:selection_change)
  end

  def test_code_editor_methods_use_current_flet_names_and_arguments
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    editor = Ruflet.code_editor("# comment\nrequire 'json'")
    page.add(editor)

    editor.fold_comment_at_line_zero
    assert_equal "fold_comment_at_line_zero", sent.last[1]["name"]

    editor.fold_at(12)
    assert_equal "fold_at", sent.last[1]["name"]
    assert_equal({ "line_number" => 12 }, sent.last[1]["args"])
  end
end
