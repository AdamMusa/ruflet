# frozen_string_literal: true

require_relative "test_helper"

# The control docs read what the user picked straight off the control:
# `event.control.value` in a handler, `field.value` / `toggle.value` later.
# Controls only exposed `props["value"]`, so those reads raised NoMethodError.
# The properties the client writes back from user interaction now have
# readers; nothing else changed.
class RufletClientStateReadersTest < Minitest::Test
  READER_FILE = File.expand_path("../lib/ruflet_ui/ruflet/ui/client_state_readers.rb", __dir__)

  def readers
    Ruflet::UI::ClientStateReaders
  end

  def build_page
    Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})
  end

  # What the Flutter renderers send when the user changes a control:
  # update_control with the new value, then the event.
  def client_change(page, control, event_name, props, data)
    page.apply_client_update(control.wire_id, props)
    page.dispatch_event(target: control.wire_id, name: event_name, data: data)
  end

  # docs/control_switch.md: `toggle = switch(label: "Dark mode", value: false)`, `toggle.value # => false`
  def test_reads_the_value_given_at_construction
    toggle = Ruflet.switch(label: "Dark mode", value: false)

    assert_equal false, toggle.value
  end

  # docs/control_dropdown.md: `field.value # => "s"` once the user picked Small.
  def test_reader_returns_what_the_user_selected_on_the_client
    page = build_page
    field = Ruflet.dropdown(
      label: "Size",
      options: [Ruflet.dropdown_option(key: "s", text: "Small"), Ruflet.dropdown_option(key: "l", text: "Large")]
    )
    page.add(field)
    assert_nil field.value

    client_change(page, field, "select", { "value" => "s" }, "s")

    assert_equal "s", field.value
  end

  # The handlers in control_switch, control_slider, control_dropdown,
  # control_date_picker and control_time_picker all read event.control.value.
  def test_documented_handlers_read_the_new_value_through_event_control
    cases = {
      "switch" => [Ruflet.switch(label: "Email notifications", value: true), "change", false],
      "slider" => [Ruflet.slider(value: 40, min: 0, max: 100, divisions: 10), "change", 70.0],
      "dropdown" => [
        Ruflet.dropdown(label: "Fruit", value: "apple", options: [
          Ruflet.dropdown_option(key: "apple", text: "Apple"),
          Ruflet.dropdown_option(key: "banana", text: "Banana")
        ]),
        "select", "banana"
      ],
      "date_picker" => [
        Ruflet.date_picker(value: "2026-01-15", first_date: "2026-01-01", last_date: "2026-12-31"),
        "change", "2026-02-01T00:00:00.000"
      ],
      "time_picker" => [Ruflet.time_picker(value: "09:30", help_text: "Pick a start time"), "change", "10:15"]
    }

    cases.each do |label, (control, event_name, data)|
      page = build_page
      observed = []
      control.on(event_name) { |event| observed << event.control.value }
      page.add(control)

      client_change(page, control, event_name, { "value" => data }, data)

      assert_equal [data], observed, label
      assert_equal data, control.value, label
    end
  end

  def test_change_event_alone_updates_what_the_reader_returns
    page = build_page
    toggle = Ruflet.switch(label: "Dark mode", value: false)
    page.add(toggle)

    page.dispatch_event(target: toggle.wire_id, name: "change", data: true)

    assert_equal true, toggle.value
  end

  def test_reader_follows_server_side_page_updates
    page = build_page
    toggle = Ruflet.switch(label: "Dark mode", value: false)
    page.add(toggle)

    page.update(toggle, value: true)

    assert_equal true, toggle.value
  end

  def test_other_client_written_properties
    page = build_page
    range = Ruflet.range_slider(start_value: 10, end_value: 80, min: 0, max: 100)
    tabs = Ruflet.tabs(selected_index: 0, length: 2, content: Ruflet.text("x"))
    tile = Ruflet.expansion_tile(title: Ruflet.text("More"), expanded: false)
    chip = Ruflet.chip(label: Ruflet.text("Tag"), selected: false)
    field = Ruflet.text_field(label: "Name", value: "")
    page.add(Ruflet.column(controls: [range, tabs, tile, chip, field]))

    page.apply_client_update(range.wire_id, "start_value" => 20.0, "end_value" => 60.0)
    page.apply_client_update(tabs.wire_id, "selected_index" => 1)
    page.apply_client_update(tile.wire_id, "expanded" => true)
    page.apply_client_update(chip.wire_id, "selected" => true)
    page.apply_client_update(field.wire_id, "value" => "Ada", "selection" => { "base_offset" => 3, "extent_offset" => 3 })

    assert_equal [20.0, 60.0], [range.start_value, range.end_value]
    assert_equal 1, tabs.selected_index
    assert_equal true, tile.expanded
    assert_equal true, chip.selected
    assert_equal "Ada", field.value
    assert_equal({ "base_offset" => 3, "extent_offset" => 3 }, field.selection)
  end

  # dropdown_m2 builds the same Dropdown control and stores `value` under the
  # same key.
  def test_dropdown_m2_reads_the_selection
    page = build_page
    field = Ruflet.dropdown_m2(options: [Ruflet.dropdown_option(key: "s", text: "Small")])
    page.add(field)

    client_change(page, field, "select", { "value" => "s" }, "s")

    assert_equal "s", field.value
  end

  def test_every_reader_in_the_table_is_defined_on_its_class
    assert_empty readers.install!, "no reader may be skipped for an existing method"

    readers.table.each do |klass, names|
      names.each do |name|
        assert klass.public_method_defined?(name), "#{klass}##{name}"
        assert_equal klass, klass.instance_method(name).owner, "#{klass}##{name}"
        assert_includes declared_properties(klass), name, "#{klass} must declare #{name}"
      end
    end
    assert_equal 51, readers.table.sum { |_klass, names| names.length }
  end

  # Readers exist only where the table says: every method defined in
  # client_state_readers.rb, public or not, across all control classes, is a
  # table entry.
  def test_no_reader_outside_the_table
    expected = readers.table.flat_map { |klass, names| names.map { |name| [klass, name] } }.sort_by(&:inspect)
    defined = control_classes.flat_map do |klass|
      (klass.public_instance_methods(false) + klass.private_instance_methods(false) +
        klass.protected_instance_methods(false)).filter_map do |name|
        location = klass.instance_method(name).source_location
        [klass, name.to_s] if location && location.first == READER_FILE
      end
    end

    assert_equal expected, defined.sort_by(&:inspect)
  end

  def test_properties_without_a_reader_still_raise
    toggle = Ruflet.switch(label: "Dark mode", value: false, on_change: ->(_e) {})
    field = Ruflet.text_field(label: "Name", tooltip: "Your name")
    dialog = Ruflet.alert_dialog(title: Ruflet.text("Hi"), open: true)
    dropdown = Ruflet.dropdown(label: "Size", text: "Small", options: [])
    button = Ruflet.icon_button(icon: "add", selected: true)
    recorder = Ruflet::UI::Services::RufletServicesComponents::AudioRecorderControl.new(data: 1)

    [[toggle, :label], [toggle, :on_change], [toggle, :not_a_property], [field, :tooltip], [field, :label],
     [dialog, :title], [button, :selected], [recorder, :data], [recorder, :key],
     [recorder, :configuration]].each do |control, name|
      assert_raises(NoMethodError, "#{control.type}.#{name}") { control.public_send(name) }
      refute_respond_to control, name
    end

    # `open` (dialogs) and Dropdown `text` keep resolving to the private
    # Kernel helpers they always did, so they still raise with a receiver.
    error = assert_raises(NoMethodError) { dialog.open }
    assert_match(/private method 'open'/, error.message)
    error = assert_raises(NoMethodError) { dropdown.text }
    assert_match(/private method 'text'/, error.message)
    refute_respond_to dialog, :open
    refute_respond_to dropdown, :text
  end

  def test_readers_take_no_arguments_and_have_no_setters
    toggle = Ruflet.switch(label: "Dark mode", value: false)

    error = assert_raises(ArgumentError) { toggle.value(1) }
    assert_equal "wrong number of arguments (given 1, expected 0)", error.message
    assert_raises(ArgumentError) { toggle.value(label: "x") }
    assert_equal(false, toggle.value { raise "a reader ignores its block" })
    assert_raises(NoMethodError) { toggle.value = true }
    refute_respond_to toggle, :value=
    assert_equal false, toggle.props["value"]
  end

  # The guard itself: no table entry collides today, so check it on classes
  # that do have such methods (public, protected, private, inherited, and the
  # private Kernel#open every object has).
  def test_a_reader_is_never_defined_over_an_existing_method
    base = Class.new do
      attr_reader :props

      def initialize(props)
        @props = props
      end

      def selected = :inherited
    end
    klass = Class.new(base) do
      def value = :public

      protected def expanded = :protected

      private def selection = :private
    end
    names = %w[value expanded selection selected open entry_mode]

    skipped = readers.define_readers([[klass, names]])

    assert_equal(%w[value expanded selection selected open].map { |name| [klass, name] }, skipped)
    control = klass.new(names.to_h { |name| [name, "prop"] })
    assert_equal :public, control.value
    assert_equal :protected, control.send(:expanded)
    assert_equal :private, control.send(:selection)
    assert_equal :inherited, control.selected
    assert_equal Kernel, klass.instance_method(:open).owner
    refute_respond_to control, :open
    assert_equal "prop", control.entry_mode
    assert_equal klass, klass.instance_method(:entry_mode).owner
  end

  def test_existing_methods_are_not_shadowed
    stepper = Ruflet.stepper(steps: [])
    menu = Ruflet.context_menu(content: Ruflet.text("Hold me"))

    assert_equal "stepper", stepper.type
    assert_equal Ruflet::UI::PlatformControlContracts::Components::ContextMenuControl, menu.method(:open).owner
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

  private

  def control_classes
    ObjectSpace.each_object(Class).select { |klass| klass <= Ruflet::Control }
  end

  def declared_properties(klass)
    return klass::KEYWORDS.map(&:to_s) if klass.const_defined?(:KEYWORDS)

    klass.instance_method(:initialize).parameters
         .select { |kind, _| kind == :key || kind == :keyreq }
         .map { |_, name| name.to_s }
  end
end
