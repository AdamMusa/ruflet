# frozen_string_literal: true

require_relative "test_helper"

# The control docs read a control's current value straight off the control:
# `event.control.value` inside a handler and `field.value` / `toggle.value`
# later on. Controls only exposed `props["value"]`, so every one of those
# documented reads raised NoMethodError. Each control now answers a zero
# argument read of any property its KEYWORDS declare, with the value it
# currently holds (client changes are applied to the control before the
# handler runs).
class RufletControlPropertyReadersTest < Minitest::Test
  def build_page
    Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})
  end

  # docs/control_switch.md: `toggle = switch(label: "Dark mode", value: false)`, `toggle.value # => false`
  def test_reads_declared_properties_given_at_construction
    toggle = Ruflet.switch(label: "Dark mode", value: false)

    assert_equal false, toggle.value
    assert_equal "Dark mode", toggle.label
  end

  def test_declared_but_unset_property_reads_nil
    field = Ruflet.dropdown(label: "Size", options: [Ruflet.dropdown_option(key: "s", text: "Small")])

    assert_nil field.value
    assert_nil field.tooltip
  end

  # docs/control_dropdown.md: `field.value # => "s"` after the user picked Small.
  # Like the Flutter client: update_control with the new value, then the event.
  def test_reader_returns_the_value_the_user_selected_on_the_client
    page = build_page
    field = Ruflet.dropdown(
      label: "Size",
      options: [Ruflet.dropdown_option(key: "s", text: "Small"), Ruflet.dropdown_option(key: "l", text: "Large")]
    )
    page.add(field)

    page.apply_client_update(field.wire_id, "value" => "s")
    page.dispatch_event(target: field.wire_id, name: "select", data: "s")

    assert_equal "s", field.value
  end

  def test_change_event_alone_updates_what_the_reader_returns
    page = build_page
    toggle = Ruflet.switch(label: "Dark mode", value: false)
    page.add(toggle)

    page.dispatch_event(target: toggle.wire_id, name: "change", data: true)

    assert_equal true, toggle.value
  end

  def test_reader_returns_values_the_client_pushed_with_update_control
    page = build_page
    name = Ruflet.text_field(label: "Name")
    page.add(name)

    page.apply_client_update(name.wire_id, "value" => "Ada")

    assert_equal "Ada", name.value
  end

  def test_reader_follows_server_side_page_updates
    page = build_page
    toggle = Ruflet.switch(label: "Dark mode", value: false)
    page.add(toggle)

    page.update(toggle, value: true, label: "Night mode")

    assert_equal true, toggle.value
    assert_equal "Night mode", toggle.label
  end

  # The handlers documented in control_switch, control_slider, control_dropdown,
  # control_date_picker and control_time_picker all read event.control.value.
  def test_documented_handlers_read_the_new_value_through_event_control
    cases = {
      "switch" => [Ruflet.switch(label: "Email notifications", value: true), "change", false, false],
      "slider" => [Ruflet.slider(value: 40, min: 0, max: 100, divisions: 10), "change", 70.0, 70.0],
      "dropdown" => [
        Ruflet.dropdown(label: "Fruit", value: "apple", options: [
          Ruflet.dropdown_option(key: "apple", text: "Apple"),
          Ruflet.dropdown_option(key: "banana", text: "Banana")
        ]),
        "select", "banana", "banana"
      ],
      "date_picker" => [
        Ruflet.date_picker(value: "2026-01-15", first_date: "2026-01-01", last_date: "2026-12-31"),
        "change", "2026-02-01T00:00:00.000", "2026-02-01T00:00:00.000"
      ],
      "time_picker" => [Ruflet.time_picker(value: "09:30", help_text: "Pick a start time"), "change", "10:15", "10:15"]
    }

    cases.each do |label, (control, event_name, data, expected)|
      page = build_page
      observed = []
      control.on(event_name) { |event| observed << event.control.value }
      page.add(control)

      # What the Flutter renderers send: updateProperties({"value": ...}), then the event.
      page.apply_client_update(control.wire_id, "value" => data)
      page.dispatch_event(target: control.wire_id, name: event_name, data: data)

      assert_equal [expected], observed, label
      assert_equal expected, control.value, label
    end
  end

  def test_controls_reads_the_live_children
    first = Ruflet.text("a")
    column = Ruflet.column(controls: [first])

    assert_equal [first], column.controls
    assert_same column.children, column.controls
  end

  def test_material2_dropdown_spellings_read_back_their_canonical_property
    field = Ruflet.dropdown_m2(max_menu_height: 200, options: [])

    assert_equal 200, field.max_menu_height
    assert_equal 200, field.menu_height
  end

  def test_respond_to_reports_declared_properties_only
    toggle = Ruflet.switch(label: "Dark mode", value: false)

    assert_respond_to toggle, :value
    assert_respond_to toggle, :label
    assert_equal false, toggle.method(:value).call
    refute_respond_to toggle, :not_a_switch_property
    refute_respond_to toggle, :on_change, "event names are not readers"
    refute_respond_to toggle, :value=, "readers do not add setters"
  end

  def test_undeclared_names_events_and_setters_still_raise
    toggle = Ruflet.switch(label: "Dark mode", value: false, on_change: ->(_e) {})

    assert_raises(NoMethodError) { toggle.not_a_switch_property }
    assert_raises(NoMethodError) { toggle.on_change }
    assert_raises(NoMethodError) { toggle.value = true }
    assert_equal false, toggle.props["value"]
  end

  def test_existing_methods_are_not_shadowed
    stepper = Ruflet.stepper(steps: [])
    menu = Ruflet.context_menu(content: Ruflet.text("Hold me"))
    toggle = Ruflet.switch(id: "dark", label: "Dark mode")

    # Stepper declares a `type` property, but Control#type stays the control type.
    assert_equal "stepper", stepper.type
    # ContextMenu#open stays its invoke method.
    assert_equal Ruflet::UI::PlatformControlContracts::Components::ContextMenuControl, menu.method(:open).owner
    assert_equal "dark", toggle.id
    assert_equal({ "label" => "Dark mode" }, toggle.props)
  end

  def test_calls_with_arguments_keep_their_previous_dispatch
    toggle = Ruflet.switch(label: "Dark mode", value: false)

    # A reader takes no arguments; anything else still reaches Kernel#method_missing
    # exactly as before.
    result = toggle.value(1)
    refute_equal false, result
    assert_kind_of Ruflet::Control, result
  end

  def test_implicit_conversions_are_unaffected
    toggle = Ruflet.switch(label: "Dark mode", value: false)

    assert_equal [toggle], [[toggle]].flatten
    assert_equal [toggle], Array(toggle)
  end

  def test_controls_without_a_schema_get_no_readers
    control = Ruflet::Control.new(type: "my_extension_widget", value: 3)

    assert_raises(NoMethodError) { control.value }
    refute_respond_to control, :value
  end
end
