# frozen_string_literal: true

require_relative "test_helper"

# The control docs read what the user picked straight off the control:
# `event.control.value` in a handler, `field.value` / `toggle.value` later.
# Controls only exposed `props["value"]`, so those reads raised NoMethodError.
# The properties the client writes back from user interaction now have
# readers, and a method the app defines itself still answers instead.
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

  # What ruflet_ui.rb installed when test_helper required "ruflet". Nothing
  # here calls install!, so this fails if ruflet_ui.rb stops calling it.
  def test_ruflet_ui_installs_every_reader_when_it_loads
    assert_equal [], readers.skipped, "ruflet_ui.rb must run install!, and no reader may be skipped"

    readers.table.each do |klass, names|
      module_name = "Ruflet::UI::ClientStateReaders::#{klass.name.split('::').last(2).join}"
      names.each do |name|
        assert klass.public_method_defined?(name), "#{klass}##{name}"
        owner = klass.instance_method(name).owner
        assert_equal module_name, owner.name, "#{klass}##{name}"
        assert_equal owner, klass.ancestors[1], "#{klass}: the reader module comes right after the class"
        refute_includes klass.instance_methods(false), name.to_sym, "#{klass} itself defines no reader"
        assert_includes declared_properties(klass), name, "#{klass} must declare #{name}"
      end
    end
    assert_equal 51, readers.table.sum { |_klass, names| names.length }
  end

  # The same, in a process that only requires "ruflet", so no earlier test
  # can have installed anything.
  def test_requiring_ruflet_is_enough
    out = run_ruby(<<~RUBY)
      require "ruflet"
      field = Ruflet.dropdown(label: "Size", value: "s", options: [])
      print [Ruflet::UI::ClientStateReaders.skipped, field.value, Ruflet.switch(value: true).respond_to?(:value)].inspect
    RUBY

    assert_equal '[[], "s", true]', out
  end

  # Readers exist only where the table says: every method defined in
  # client_state_readers.rb, public or not, that a control class reaches
  # through a module it includes itself, is a table entry.
  def test_no_reader_outside_the_table
    expected = readers.table.flat_map { |klass, names| names.map { |name| [klass, name] } }.sort_by(&:inspect)
    defined = control_classes.flat_map do |klass|
      own_modules = klass.ancestors.take_while { |ancestor| ancestor != klass.superclass } - [klass]
      own_modules.flat_map do |mod|
        (mod.public_instance_methods(false) + mod.private_instance_methods(false) +
          mod.protected_instance_methods(false)).filter_map do |name|
          location = mod.instance_method(name).source_location
          [klass, name.to_s] if location && location.first == READER_FILE
        end
      end
    end

    assert_equal expected, defined.sort_by(&:inspect)
    reader_modules = readers.constants.map { |name| readers.const_get(name) }.grep(Module).reject { |mod| mod.is_a?(Class) }
    assert_equal 42, reader_modules.length
    reader_modules.each do |mod|
      assert_equal 1, control_classes.count { |klass| klass.include?(mod) && !klass.superclass.include?(mod) }, mod.name
    end
  end

  # An app on v0.0.23 could not read these, so it may have added a reader of
  # its own after loading Ruflet. Whatever it defined still answers, as it does
  # on main, in every place an app can put one.
  def test_app_methods_added_after_load_still_win
    dropdown = Ruflet.dropdown(label: "Size", options: [])
    toggle = Ruflet.switch(label: "Dark mode", value: false)
    tabs = Ruflet.tabs(selected_index: 1, length: 2, content: Ruflet.text("x"))
    field = Ruflet.text_field(label: "Name", value: "Ada")

    # On Ruflet::Control (main gives "(unset)" here too).
    with_app_methods(Ruflet::Control, <<~RUBY) do
      def value = props["value"].nil? ? "(unset)" : props["value"]
    RUBY
      assert_equal "(unset)", dropdown.value
      assert_equal false, toggle.value
      assert_equal "Ada", field.value
    end
    assert_nil dropdown.value, "the reader answers again once the app method is gone"

    # On the PlatformControl base of the Components classes.
    with_app_methods(Ruflet::UI::PlatformControlContracts::Components::PlatformControl, <<~RUBY) do
      def value = "platform"
    RUBY
      assert_equal "platform", toggle.value
      assert_equal 1, tabs.selected_index
    end

    # In a framework module a table class includes (TextFieldControl
    # includes TextInputMethods).
    with_app_methods(Ruflet::UI::Controls::TextInputMethods, <<~RUBY) do
      def value = "text input"
    RUBY
      assert_equal "text input", field.value
      assert_equal false, toggle.value
    end

    # On the table class itself, and on the object.
    with_app_methods(Ruflet::UI::Controls::RufletComponents::TabsControl, "def selected_index = :class") do
      assert_equal :class, tabs.selected_index
    end
    tabs.define_singleton_method(:selected_index) { :object }
    assert_equal :object, tabs.selected_index
    tabs.singleton_class.send(:remove_method, :selected_index)
    assert_equal 1, tabs.selected_index
  end

  # Modules cannot be taken out again, so these run in their own process.
  def test_app_modules_added_after_load_still_win
    out = run_ruby(<<~RUBY)
      require "ruflet"
      tabs = Ruflet.tabs(selected_index: 1, length: 2, content: Ruflet.text("x"))
      field = Ruflet.text_field(label: "Name", value: "Ada")
      results = [tabs.selected_index]

      # Included into, then prepended to, Ruflet::Control.
      Ruflet::Control.include(Module.new { def selected_index = :included })
      results << tabs.selected_index
      Ruflet::Control.prepend(Module.new { def selected_index = :prepended })
      results << tabs.selected_index

      # Included into the table class itself.
      Ruflet::UI::Controls::RufletComponents::TabsControl.include(Module.new { def selected_index = "from module" })
      results << tabs.selected_index

      # Included into a framework module the table class already includes.
      Ruflet::UI::Controls::TextInputMethods.include(Module.new { def value = :text_input_module })
      results << field.value

      print results.inspect
    RUBY

    assert_equal '[1, :included, :prepended, "from module", :text_input_module]', out
  end

  def test_app_methods_get_the_arguments_and_block
    toggle = Ruflet.switch(label: "Dark mode")

    with_app_methods(Ruflet::Control, <<~RUBY) do
      def value(fallback = :none, upcase: false, &block)
        result = props.fetch("value", fallback)
        result = result.to_s.upcase if upcase
        block ? block.call(result) : result
      end
    RUBY
      assert_equal :none, toggle.value
      assert_equal "given", toggle.value("given")
      assert_equal "GIVEN", toggle.value("given", upcase: true)
      assert_equal [:none], toggle.value { |result| [result] }
      assert_equal(-1, toggle.method(:value).arity)
    end
  end

  # Visibility is the app's business: a private or protected method it
  # defines on a control class answers send and calls from inside the class
  # as before. `control.value` now reaches it too; on main that raised
  # NoMethodError ("private method 'value' called").
  def test_private_and_protected_app_methods_still_answer
    toggle = Ruflet.switch(label: "Dark mode", value: false)

    with_app_methods(Ruflet::Control, "private def value = :private") do
      assert_equal :private, toggle.send(:value)
      assert_equal :private, toggle.instance_eval { value }
      assert_equal :private, toggle.value
    end
    with_app_methods(Ruflet::Control, "protected def value = :protected") do
      assert_equal :protected, toggle.send(:value)
      assert_equal :protected, toggle.value
    end
  end

  # A method_missing the app added to answer property reads keeps answering.
  def test_an_app_method_missing_still_answers
    toggle = Ruflet.switch(label: "Dark mode", value: false)

    with_app_methods(Ruflet::Control, <<~RUBY) do
      def method_missing(name, *args, **options, &block)
        name == :value ? [:app_method_missing, props["value"], args] : super
      end
    RUBY
      assert_equal [:app_method_missing, false, []], toggle.value
      assert_equal [:app_method_missing, false, [1]], toggle.value(1)
    end
    with_app_methods(Ruflet::Control, "def method_missing(name, *args, **options, &block) = super") do
      error = assert_raises(NoMethodError) { toggle.value }
      assert_equal :value, error.name
    end
    assert_equal false, toggle.value
  end

  # One the app adds to Object for everything answers too, as on main.
  def test_an_app_method_missing_on_object_still_answers
    toggle = Ruflet.switch(label: "Dark mode", value: false)
    source = <<~RUBY
      def method_missing(name, *args, **options, &block)
        name == :value ? :global_method_missing : super
      end
    RUBY

    # Ruby warns that redefining Object#method_missing may loop; this one
    # does not.
    with_app_methods(Object, source, quiet: true) do
      assert_equal :global_method_missing, toggle.value
    end
    assert_equal false, toggle.value
  end

  # An app that wraps Ruflet's own Kernel#method_missing (it sees every
  # missing method) gets every call it got on main: the readers hand all of
  # them to it, so names it does not answer raise as they did on main. In
  # its own process: Kernel's method_missing is Ruflet's DSL fallback.
  def test_an_app_wrapping_the_kernel_method_missing_still_answers
    out = run_ruby(<<~RUBY)
      require "ruflet"
      toggle = Ruflet.switch(label: "Dark mode", value: false)
      tabs = Ruflet.tabs(selected_index: 1, length: 2, content: Ruflet.text("x"))
      before = [toggle.value, tabs.selected_index]
      module Kernel
        alias_method :ruflet_method_missing, :method_missing
        private :ruflet_method_missing
        private def method_missing(name, *args, **props, &block)
          name == :value ? :wrapped : ruflet_method_missing(name, *args, **props, &block)
        end
      end
      unanswered = begin
        tabs.selected_index
      rescue NoMethodError => e
        e.name
      end
      print [before, toggle.value, unanswered].inspect
    RUBY

    assert_equal "[[false, 1], :wrapped, :selected_index]", out
  end

  # An app subclass of a table class that answers through its own
  # method_missing keeps answering; plain subclasses get the reader.
  def test_an_app_subclass_method_missing_still_answers
    switch_class = Ruflet::UI::Controls::RufletComponents::SwitchControl
    answering = Class.new(switch_class) do
      def method_missing(name, *args, **options, &block)
        name == :value ? [:subclass, props["value"]] : super
      end
    end
    plain = Class.new(switch_class)

    assert_equal [:subclass, true], answering.new(value: true).value
    assert_equal true, plain.new(value: true).value
  end

  # The same for one object: a method_missing defined on it, or in a module
  # it is extended with.
  def test_an_object_method_missing_still_answers
    toggle = Ruflet.switch(label: "Dark mode", value: false)
    extended = Ruflet.switch(label: "Extended", value: false)
    def toggle.method_missing(name, *args, **options, &block)
      name == :value ? :object_method_missing : super
    end
    extended.extend(Module.new do
      def method_missing(name, *args, **options, &block)
        name == :value ? :extended_method_missing : super
      end
    end)

    assert_equal :object_method_missing, toggle.value
    assert_equal :extended_method_missing, extended.value
    assert_equal false, Ruflet.switch(label: "Other", value: false).value
  end

  # Methods on Object or Kernel count too. A public one is what
  # `control.value` called on main. A private one (a top-level `def` in a
  # script) is what a call without a receiver from inside the control's own
  # methods reached on main, so the reader hands those calls to it as well.
  def test_object_and_kernel_methods_still_answer
    toggle = Ruflet.switch(label: "Dark mode", value: false)

    with_app_methods(Object, "def value = :object") do
      assert_equal :object, toggle.value
    end
    with_app_methods(Kernel, "def value = :kernel") do
      assert_equal :kernel, toggle.value
    end
    with_app_methods(Object, "private def value = :top_level_helper") do
      assert_equal :top_level_helper, toggle.send(:value)
      assert_equal :top_level_helper, toggle.instance_eval { value }
      assert_equal :top_level_helper, toggle.value
    end
    assert_equal false, toggle.value
  end

  # The same with a real script: a top-level `def` after `require "ruflet"`,
  # called from a method the script adds to a control class.
  def test_a_top_level_helper_still_answers_calls_from_control_methods
    out = run_ruby(<<~RUBY)
      require "ruflet"
      def selected_index = :top_level_helper
      class Ruflet::UI::Controls::RufletComponents::TabsControl
        def describe = selected_index
      end
      tabs = Ruflet.tabs(selected_index: 1, length: 2, content: Ruflet.text("x"))
      print [tabs.describe, tabs.selected_index, Ruflet.chip(label: Ruflet.text("t"), selected: true).selected].inspect
    RUBY

    assert_equal "[:top_level_helper, :top_level_helper, true]", out
  end

  # An app method that already exists when Ruflet loads keeps the reader
  # from being defined at all.
  def test_app_method_defined_before_ruflet_loads_wins
    out = run_ruby(<<~RUBY)
      module Ruflet
        class Control
          def value = "app"
        end
      end
      require "ruflet"
      readers = Ruflet::UI::ClientStateReaders
      tabs = Ruflet.tabs(selected_index: 1, length: 2, content: Ruflet.text("x"))
      skipped = readers.skipped.map { |_klass, name| name }.uniq
      value_pairs = readers.table.sum { |_klass, names| names.count("value") }
      print [skipped, readers.skipped.length == value_pairs, Ruflet.dropdown(options: []).value,
             Ruflet.switch(value: true).value, tabs.selected_index].inspect
    RUBY

    assert_equal '[["value"], true, "app", "app", 1]', out
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
    assert_match(/private method [`']open'/, error.message)
    error = assert_raises(NoMethodError) { dropdown.text }
    assert_match(/private method [`']text'/, error.message)
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
    reader_module = klass.instance_method(:entry_mode).owner
    assert_instance_of Module, reader_module
    assert_equal [klass, reader_module], klass.ancestors.first(2)
    assert_nil reader_module.name, "an anonymous class gets an anonymous reader module"
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

  # Evaluates `source` in `owner` the way an app reopens a class or module,
  # runs the block, then removes the methods it added again.
  def with_app_methods(owner, source, quiet: false)
    before = own_methods(owner)
    verbose = $VERBOSE
    $VERBOSE = nil if quiet
    begin
      owner.class_eval(source)
    ensure
      $VERBOSE = verbose
    end
    added = own_methods(owner) - before
    yield
  ensure
    added&.each { |name| owner.send(:remove_method, name) }
  end

  def own_methods(owner)
    owner.instance_methods(false) + owner.private_instance_methods(false)
  end

  def run_ruby(script)
    lib = File.expand_path("../lib", __dir__)
    out = IO.popen([RbConfig.ruby, "-I", lib, "-e", script], err: [:child, :out], &:read)
    assert $?.success?, out
    out
  end

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
