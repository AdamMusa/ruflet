# frozen_string_literal: true

require_relative "test_helper"

class RufletAutoCompleteCompatibilityTest < Minitest::Test
  def test_auto_complete_accepts_positional_suggestions_and_serializes_current_flet_props
    control = Ruflet.auto_complete(
      [
        Ruflet.auto_complete_suggestion("one 1", value: "One"),
        Ruflet.autocomplete_suggestion(value: "Two")
      ],
      value: "O",
      suggestions_max_height: 160,
      width: 200,
      on_change: ->(_event) {},
      on_select: ->(_event) {}
    )

    patch = control.to_patch

    assert_equal "AutoComplete", patch["_c"]
    assert_equal "O", patch["value"]
    assert_equal 160, patch["suggestions_max_height"]
    assert_equal 200, patch["width"]
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_select"]

    first, second = patch["suggestions"]
    assert_equal "AutoCompleteSuggestion", first["_c"]
    assert_equal "one 1", first["key"]
    assert_equal "One", first["value"]
    assert_equal "Two", second["key"]
    assert_equal "Two", second["value"]
  end

  def test_compact_aliases_use_same_controls
    suggestion = Ruflet.autocompletesuggestion("one")
    control = Ruflet.autocomplete([suggestion])

    assert_equal "autocomplete", control.type
    assert_equal "AutoComplete", control.to_patch["_c"]
    assert_equal "autocompletesuggestion", suggestion.type
    assert_equal "AutoCompleteSuggestion", suggestion.to_patch["_c"]
  end

  def test_auto_complete_defaults_match_flet
    control = Ruflet.auto_complete

    assert_equal [], control.props["suggestions"]
    assert_equal "", control.props["value"]
    assert_equal 200, control.props["suggestions_max_height"]
  end

  def test_auto_complete_suggestion_requires_key_or_value_and_falls_back_like_flet
    assert_raises(ArgumentError) { Ruflet.auto_complete_suggestion }

    keyed = Ruflet.auto_complete_suggestion("one")
    valued = Ruflet.auto_complete_suggestion(value: "Two")

    assert_equal "one", keyed.props["key"]
    assert_equal "one", keyed.props["value"]
    assert_equal "Two", valued.props["key"]
    assert_equal "Two", valued.props["value"]
  end

  def test_change_event_updates_value_before_handler
    observed = nil
    control = Ruflet.auto_complete(value: "O", on_change: ->(event) { observed = [event.value, event.control.props["value"]] })
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(control)

    page.dispatch_event(target: control.wire_id, name: "change", data: { "value" => "One" })

    assert_equal "One", control.props["value"]
    assert_equal ["One", "One"], observed
  end

  def test_select_event_exposes_selected_suggestion
    observed = nil
    control = Ruflet.auto_complete(
      [Ruflet.auto_complete_suggestion("one 1", value: "One")],
      on_select: ->(event) { observed = [event.selection["key"], event.selection["value"], event.value] }
    )
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(control)

    page.dispatch_event(
      target: control.wire_id,
      name: "select",
      data: { "selection" => { "key" => "one 1", "value" => "One" }, "value" => "One" }
    )

    assert_equal ["one 1", "One", "One"], observed
    assert_equal "One", control.props["value"]
  end
end
