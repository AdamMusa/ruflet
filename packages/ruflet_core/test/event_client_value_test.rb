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
