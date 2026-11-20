# frozen_string_literal: true

require_relative "test_helper"

# The client sends a control's value as a plain String event payload, right
# after it synced the same String into the control with update_control:
# textfield.dart (change), material_dropdown.dart (select, text_change) and
# radio_group.dart (change). These tests replay that order. The String is
# what the user typed or picked, so it must reach the handler as a String,
# also when it happens to look like JSON.
class EventClientValueTest < Minitest::Test
  JSON_LOOKING = ["123", "2.50", " 42", "1e3", "-7", "true", "false", "null", "[1]", "{\"a\":1}", "\"q\""].freeze

  def setup
    @page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})
  end

  # What the client sends when the user types or picks +value+.
  def client_sends(control, name, value, prop: "value")
    @page.apply_client_update(control.wire_id, { prop => value })
    @page.dispatch_event(target: control.wire_id, name: name, data: value)
  end

  def test_text_field_change_and_submit_data_is_the_typed_text
    seen = []
    field = Ruflet.text_field(
      on_change: ->(e) { seen << [:change, e.data, e.value, e.control.props["value"]] },
      on_submit: ->(e) { seen << [:submit, e.data, e.value] }
    )
    @page.add(field)

    JSON_LOOKING.each do |typed|
      client_sends(field, "change", typed)
      # onFieldSubmitted sends the text alone; the last change synced it.
      @page.dispatch_event(target: field.wire_id, name: "submit", data: typed)
    end

    expected = JSON_LOOKING.flat_map { |typed| [[:change, typed, typed, typed], [:submit, typed, typed]] }
    assert_equal expected, seen
  end

  def test_typed_text_stays_the_fields_value_for_a_later_render
    field = Ruflet.text_field(value: "", on_change: ->(_e) {})
    @page.add(field)

    client_sends(field, "change", "2.50")

    assert_equal "2.50", field.props["value"]
    assert_equal "2.50", field.to_patch["value"]
  end

  def test_validator_form_change_and_form_values_see_the_typed_text
    validated = []
    form_seen = []
    field = nil
    form = Ruflet.form(autovalidate_mode: "always", on_change: ->(e) { form_seen << [e.data, e.value] }) do
      field = text_field(key: "zip", on_change: ->(_e) {},
                         validator: ->(v) { validated << v; "Digits only" unless v.strip.match?(/\A\d+\z/) })
    end
    @page.add(form)

    client_sends(field, "change", "12345")

    assert_equal [["12345", "12345"]], form_seen
    assert_equal({ "zip" => "12345" }, form.values)
    # "always" also validated the empty field when the form was added.
    assert_equal "12345", validated.last
    assert(validated.all? { |v| v.is_a?(String) }, validated.inspect)
    assert_nil field.props["error"]
  end

  def test_string_option_keys_and_radio_values_stay_strings
    seen = []
    dropdown = Ruflet.dropdown(
      value: "1",
      options: [Ruflet.dropdown_option(key: "1", text: "One"), Ruflet.dropdown_option(key: "2", text: "Two")],
      on_select: ->(e) { seen << [:select, e.data, e.control.props["value"]] }
    )
    text_only = Ruflet.dropdown(
      options: [Ruflet.dropdown_option(text: "10"), Ruflet.dropdown_option(text: "20")],
      on_select: ->(e) { seen << [:text_only, e.data] }
    )
    group = Ruflet.radio_group(
      value: "10",
      content: Ruflet.column(controls: [Ruflet.radio(value: "10"), Ruflet.radio(value: "20")]),
      on_change: ->(e) { seen << [:radio, e.data, e.value, e.control.props["value"]] }
    )
    @page.add(Ruflet.column(controls: [dropdown, text_only, group]))

    client_sends(dropdown, "select", "2")
    client_sends(text_only, "select", "20")
    client_sends(group, "change", "20")

    assert_equal [[:select, "2", "2"], [:text_only, "20"], [:radio, "20", "20", "20"]], seen
  end

  # The renderer reads an option key or radio value as a String, so an app
  # that declares Integer (or Float, or boolean) choices gets them back as
  # "2". Those handlers keep receiving the declared value, as before.
  def test_non_string_option_keys_and_radio_values_keep_their_declared_type
    seen = []
    ints = Ruflet.dropdown(
      value: 1,
      options: [Ruflet.dropdown_option(key: 1, text: "One"), Ruflet.dropdown_option(key: 2, text: "Two")],
      on_select: ->(e) { seen << [:ints, e.data] }
    )
    floats = Ruflet.dropdown(
      options: [Ruflet.dropdown_option(key: 0.5, text: "Half"), Ruflet.dropdown_option(key: 2.5, text: "More")],
      on_select: ->(e) { seen << [:floats, e.data] }
    )
    bools = Ruflet.dropdown(
      options: [Ruflet.dropdown_option(key: true, text: "Yes"), Ruflet.dropdown_option(key: false, text: "No")],
      on_select: ->(e) { seen << [:bools, e.data] }
    )
    group = Ruflet.radio_group(
      value: 10,
      content: Ruflet.column(controls: [Ruflet.radio(value: 10), Ruflet.radio(value: 20)]),
      on_change: ->(e) { seen << [:radio, e.data, e.control.props["value"]] }
    )
    @page.add(Ruflet.column(controls: [ints, floats, bools, group]))

    client_sends(ints, "select", "2")
    client_sends(floats, "select", "2.5")
    client_sends(bools, "select", "false")
    client_sends(group, "change", "20")

    assert_equal [[:ints, 2], [:floats, 2.5], [:bools, false], [:radio, 20, 20]], seen
  end

  # Ruflet.option (dropdown_m2) is read like a dropdown_option, and an
  # option without a key is read by its text, also an Integer text.
  def test_dropdown_m2_keys_and_text_only_options_keep_their_declared_type
    seen = []
    m2 = Ruflet.dropdown_m2(
      options: [Ruflet.option(key: 1), Ruflet.option(key: 2)],
      on_change: ->(e) { seen << [:m2, e.data] }
    )
    m2_text_only = Ruflet.dropdown_m2(
      options: [Ruflet.option(text: 10), Ruflet.option(text: 20)],
      on_change: ->(e) { seen << [:m2_text_only, e.data] }
    )
    text_only = Ruflet.dropdown(
      options: [Ruflet.dropdown_option(text: 10), Ruflet.dropdown_option(text: 20)],
      on_select: ->(e) { seen << [:text_only, e.data] }
    )
    @page.add(Ruflet.column(controls: [m2, m2_text_only, text_only]))

    client_sends(m2, "select", "2")
    client_sends(m2_text_only, "select", "20")
    client_sends(text_only, "select", "20")

    assert_equal [[:m2, 2], [:m2_text_only, 20], [:text_only, 20]], seen
  end

  # material_dropdown_m2.dart reports an option with neither key nor text by
  # its wire id, which handlers got as an Integer before.
  def test_an_option_without_key_or_text_is_reported_by_its_wire_id
    seen = []
    dropdown = Ruflet.dropdown_m2(
      options: [Ruflet.option(content: Ruflet.text("a")), Ruflet.option(content: Ruflet.text("b"))],
      on_change: ->(e) { seen << e.data }
    )
    @page.add(dropdown)
    picked = dropdown.props["options"][1]

    client_sends(dropdown, "select", picked.wire_id.to_s)

    assert_equal [picked.wire_id], seen
  end

  # The client sends "2" for both of these options, so the pick cannot be
  # told apart: the handler gets 2, as before.
  def test_choices_declaring_both_2_and_the_string_2_keep_the_decoded_value
    seen = []
    dropdown = Ruflet.dropdown(
      options: [Ruflet.dropdown_option(key: 2, text: "Two"), Ruflet.dropdown_option(key: "2", text: "String two")],
      on_select: ->(e) { seen << e.data }
    )
    @page.add(dropdown)

    client_sends(dropdown, "select", "2")

    assert_equal [2], seen
  end

  # Radios inside a nested RadioGroup (or the options of a nested Dropdown)
  # belong to that field, not to the group the user picked in.
  def test_a_radio_group_counts_only_its_own_radios
    seen = []
    group = Ruflet.radio_group(
      content: Ruflet.column(controls: [
        Ruflet.radio(value: "a"),
        Ruflet.radio(value: "20"),
        Ruflet.radio_group(content: Ruflet.radio(value: 20)),
        Ruflet.dropdown(options: [Ruflet.dropdown_option(key: 20)])
      ]),
      on_change: ->(e) { seen << e.data }
    )
    @page.add(group)

    client_sends(group, "change", "20")

    assert_equal ["20"], seen
  end

  # Only a Dropdown or a RadioGroup reports one of its choices as its value.
  # A TextField reports the typed text, whatever controls it holds.
  def test_a_text_field_holding_choices_reports_the_typed_text
    seen = []
    with_radio = Ruflet.text_field(suffix: Ruflet.radio(value: 5), on_change: ->(e) { seen << e.data })
    with_dropdown = Ruflet.text_field(
      suffix: Ruflet.dropdown(options: [Ruflet.dropdown_option(key: 5)]),
      on_change: ->(e) { seen << e.data }
    )
    @page.add(Ruflet.column(controls: [with_radio, with_dropdown]))

    client_sends(with_radio, "change", "5")
    client_sends(with_radio, "change", "6")
    client_sends(with_dropdown, "change", "5")

    assert_equal %w[5 6 5], seen
  end

  # A Symbol key reaches the wire as its String, and comes back as that
  # String, whether it reads like a word or like a number.
  def test_symbol_option_keys_come_back_as_their_string
    seen = []
    dropdown = Ruflet.dropdown(
      options: [Ruflet.dropdown_option(key: :"1", text: "One"), Ruflet.dropdown_option(key: :small, text: "Small")],
      on_select: ->(e) { seen << e.data }
    )
    @page.add(dropdown)

    client_sends(dropdown, "select", "1")
    client_sends(dropdown, "select", "small")

    assert_equal %w[1 small], seen
  end

  # code_editor.dart syncs the edited text into value, then sends it.
  def test_code_editor_change_is_the_edited_text
    seen = []
    editor = Ruflet.code_editor(value: "", on_change: ->(e) { seen << e.data })
    @page.add(editor)

    ["{}", "123", "[1]"].each { |text| client_sends(editor, "change", text) }

    assert_equal ["{}", "123", "[1]"], seen
  end

  # material_search_bar.dart syncs the text with its capitalization applied
  # and sends it as typed, so the two differ; the handler still gets the
  # typed text.
  def test_search_bar_change_and_submit_are_the_typed_text_with_capitalization
    seen = []
    bar = Ruflet.search_bar(
      capitalization: "characters",
      on_change: ->(e) { seen << [:change, e.data] },
      on_submit: ->(e) { seen << [:submit, e.data] }
    )
    @page.add(bar)

    { "{\"a\":1}" => "{\"A\":1}", "\"q\"" => "\"Q\"", "true" => "TRUE", "1e5" => "1E5" }.each do |typed, synced|
      @page.apply_client_update(bar.wire_id, { "value" => synced })
      @page.dispatch_event(target: bar.wire_id, name: "change", data: typed)
    end
    @page.apply_client_update(bar.wire_id, { "value" => "NULL" })
    @page.dispatch_event(target: bar.wire_id, name: "submit", data: "null")

    assert_equal [[:change, "{\"a\":1}"], [:change, "\"q\""], [:change, "true"], [:change, "1e5"], [:submit, "null"]], seen
  end

  def test_dropdown_text_change_is_the_typed_text
    seen = []
    dropdown = Ruflet.dropdown(
      options: [Ruflet.dropdown_option(key: 1, text: "One"), Ruflet.dropdown_option(key: 2, text: "Two")],
      on_text_change: ->(e) { seen << e.data }
    )
    @page.add(dropdown)

    client_sends(dropdown, "text_change", "2", prop: "text")
    client_sends(dropdown, "text_change", "null", prop: "text")

    assert_equal %w[2 null], seen
  end

  # After the user picks the option with Integer key 2, the dropdown's value
  # is "2"; typing "2" into it is still text.
  def test_dropdown_text_change_matching_the_picked_key_is_the_typed_text
    seen = []
    dropdown = Ruflet.dropdown(
      editable: true,
      options: [Ruflet.dropdown_option(key: 1, text: "One"), Ruflet.dropdown_option(key: 2, text: "Two")],
      on_select: ->(e) { seen << [:select, e.data] },
      on_text_change: ->(e) { seen << [:text_change, e.data] }
    )
    @page.add(dropdown)

    client_sends(dropdown, "select", "2")
    client_sends(dropdown, "text_change", "2", prop: "text")

    assert_equal [[:select, 2], [:text_change, "2"]], seen
  end

  # Payloads that are not the control's own value decode as before: JSON
  # objects and arrays, and the scalars other events carry (a PopupMenuButton
  # select sends the picked item's id as a String).
  def test_payloads_that_are_not_the_controls_value_decode_as_before
    seen = []
    field = Ruflet.text_field(value: "typed", on_change: ->(e) { seen << [:field, e.data] })
    menu = Ruflet.popup_menu_button([Ruflet.popup_menu_item("Edit")], on_select: ->(e) { seen << [:menu, e.data] })
    tile = Ruflet.container(on_click: ->(e) { seen << [:click, e.data] })
    @page.add(Ruflet.column(controls: [field, menu, tile]))

    @page.dispatch_event(target: field.wire_id, name: "change", data: "{\"value\":\"x\"}")
    @page.dispatch_event(target: field.wire_id, name: "change", data: "[1,2]")
    @page.dispatch_event(target: field.wire_id, name: "change", data: { "value" => "y" })
    @page.dispatch_event(target: menu.wire_id, name: "select", data: "42")
    @page.dispatch_event(target: tile.wire_id, name: "click", data: "{\"x\":1}")
    @page.dispatch_event(target: tile.wire_id, name: "click", data: true)

    assert_equal [
      [:field, { "value" => "x" }],
      [:field, [1, 2]],
      [:field, { "value" => "y" }],
      [:menu, 42],
      [:click, { "x" => 1 }],
      [:click, true]
    ], seen
  end
end
