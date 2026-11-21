# frozen_string_literal: true

require_relative "test_helper"

# event.value for every control that fires "select", with the payload the
# client really sends (ruflet-engine and ruflet-template renderers):
# - material_dropdown.dart syncs "value" and sends the option's key as a
#   String; the Cupertino sheet (cupertino_input_controls.dart) the same;
# - material_chip.dart sends the new selected bool, and the Cupertino chip
#   (cupertino_content_controls.dart) the same;
# - material_popup_menu_button.dart sends the picked item's id as a String,
#   and the Cupertino menu (cupertino_navigation_controls.dart) the same;
# - material_auto_complete.dart and context_menu.dart send a Map.
# The handler's value is the pick, as e.data is. Nothing else changes: the
# props the client already synced, and what later patches send.
class SelectEventValueTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" },
                             sender: ->(action, payload) { @sent << [action, payload] })
    @seen = []
  end

  def record(tag)
    ->(e) { @seen << [tag, e.data, e.value] }
  end

  def test_dropdown_select_value_is_the_picked_key
    dropdown = Ruflet.dropdown(value: "a", options: [Ruflet.dropdown_option(key: "a"), Ruflet.dropdown_option(key: "b")],
                               on_select: record(:dropdown))
    @page.add(dropdown)

    @page.apply_client_update(dropdown.wire_id, { "value" => "b" })
    @page.dispatch_event(target: dropdown.wire_id, name: "select", data: "b")

    assert_equal [[:dropdown, "b", "b"]], @seen
    assert_equal "b", dropdown.props["value"]
  end

  def test_dropdown_select_value_keeps_the_declared_key_type_and_props_stay_as_synced
    dropdown = Ruflet.dropdown(value: 1, options: [Ruflet.dropdown_option(key: 1, text: "One"), Ruflet.dropdown_option(key: 2, text: "Two")],
                               on_select: record(:ints))
    @page.add(dropdown)

    @page.apply_client_update(dropdown.wire_id, { "value" => "2" })
    @page.dispatch_event(target: dropdown.wire_id, name: "select", data: "2")

    assert_equal [[:ints, 2, 2]], @seen
    # The value the client synced, untouched by the event.
    assert_equal "2", dropdown.props["value"]
  end

  def test_dropdown_m2_change_handler_value_is_the_picked_key
    dropdown = Ruflet.dropdown_m2([Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")], value: "red",
                                  on_change: ->(e) { @seen << [e.name, e.data, e.value] })
    @page.add(dropdown)

    @page.apply_client_update(dropdown.wire_id, { "value" => "blue" })
    @page.dispatch_event(target: dropdown.wire_id, name: "select", data: "blue")

    assert_equal [["change", "blue", "blue"]], @seen
  end

  def test_chip_select_value_is_the_new_selected_state
    chip = Ruflet.chip("Filter", selected: false, on_select: record(:chip))
    @page.add(chip)

    @page.apply_client_update(chip.wire_id, { "selected" => true })
    @page.dispatch_event(target: chip.wire_id, name: "select", data: true)
    @page.apply_client_update(chip.wire_id, { "selected" => false })
    @page.dispatch_event(target: chip.wire_id, name: "select", data: false)

    assert_equal [[:chip, true, true], [:chip, false, false]], @seen
    assert_equal false, chip.props["selected"]
  end

  def test_popup_menu_select_value_is_the_picked_item_id_and_adds_no_prop
    item = Ruflet.popup_menu_item("Edit")
    menu = Ruflet.popup_menu_button([item], on_select: record(:menu))
    column = Ruflet.column(controls: [menu])
    @page.add(column)
    props_before = menu.props.keys.sort

    @page.dispatch_event(target: menu.wire_id, name: "select", data: item.wire_id.to_s)

    assert_equal [[:menu, item.wire_id, item.wire_id]], @seen
    assert_equal props_before, menu.props.keys.sort
    @sent.clear
    @page.update(column, controls: [menu, Ruflet.text("new")])
    refute_includes @sent.inspect, "\"selected\"", "a select leaves no prop for later patches to send"
  end

  def test_map_payloads_keep_their_value
    auto = Ruflet.auto_complete(suggestions: [Ruflet.auto_complete_suggestion(key: "k", value: "v")], on_select: record(:auto))
    menu = Ruflet.context_menu(Ruflet.text("Target"), items: [Ruflet.popup_menu_item("Open")], on_select: record(:context))
    @page.add(Ruflet.column(controls: [auto, menu]))

    auto_payload = { "index" => 0, "selection" => { "key" => "k", "value" => "v" } }
    context_payload = { "item_id" => 7, "item_index" => 0, "item_count" => 1, "trigger" => "primary" }
    @page.dispatch_event(target: auto.wire_id, name: "select", data: auto_payload)
    @page.dispatch_event(target: menu.wire_id, name: "select", data: context_payload)

    assert_equal [[:auto, auto_payload, "v"], [:context, context_payload, nil]], @seen
  end

  def test_select_without_payload_has_no_value
    menu = Ruflet.popup_menu_button([Ruflet.popup_menu_item("Edit")], on_select: record(:menu))
    @page.add(menu)

    @page.dispatch_event(target: menu.wire_id, name: "select", data: nil)

    assert_equal [[:menu, nil, nil]], @seen
  end
end
