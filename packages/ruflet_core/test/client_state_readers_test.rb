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

  # `ruflet run` hot reload drops every watched file from $LOADED_FEATURES and
  # loads the script again, so when the framework sources sit inside the app
  # directory, `require "ruflet"` loads ruflet_ui.rb a second time and
  # Kernel#method_missing is defined again. That is still Ruflet's own, so the
  # readers keep answering, and an app that wraps it afterwards still gets the
  # call. Loading the readers file again adds no warning, and the extension
  # helper recorded before the reload is still told apart from an app method.
  def test_readers_survive_the_framework_being_loaded_again
    out = run_ruby(<<~RUBY)
      require "ruflet"
      require "stringio"
      class ExpandedControl < Ruflet::Control
        def initialize(**props) = super(type: "expanded", **props)
      end
      Ruflet::Extensions.register_control(:expanded, control_class: ExpandedControl)
      tile = Ruflet.expansion_tile(title: Ruflet.text("More"), expanded: true)
      toggle = Ruflet.switch(label: "Dark mode", value: false)
      before = toggle.value
      first_method_missing = Kernel.instance_method(:method_missing)
      lib = #{File.expand_path('../lib', __dir__).inspect}
      roots = [lib, File.realpath(lib)].map { |root| root + "/" }
      $LOADED_FEATURES.reject! { |feature| roots.any? { |root| feature.start_with?(root) } }
      $stderr = StringIO.new
      require "ruflet"
      warnings = $stderr.string.lines.grep(/client_state_readers/)
      $stderr = STDERR
      reloaded = Kernel.instance_method(:method_missing) != first_method_missing
      after = [toggle.value, Ruflet.switch(value: true).value, tile.expanded]
      module Kernel
        alias_method :ruflet_method_missing, :method_missing
        private :ruflet_method_missing
        private def method_missing(name, *args, **props, &block)
          name == :value ? :wrapped : ruflet_method_missing(name, *args, **props, &block)
        end
      end
      print [reloaded, before, after, warnings, toggle.value].inspect
    RUBY

    assert_equal "[true, false, [false, true, true], [], :wrapped]", out
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

  # A method_missing the app added to answer property reads keeps answering,
  # and gets the arguments, keyword arguments and block, as on main.
  def test_an_app_method_missing_still_answers
    toggle = Ruflet.switch(label: "Dark mode", value: false)

    with_app_methods(Ruflet::Control, <<~RUBY) do
      def method_missing(name, *args, **options, &block)
        name == :value ? [:app_method_missing, props["value"], args, options, block&.call] : super
      end
    RUBY
      assert_equal [:app_method_missing, false, [], {}, nil], toggle.value
      assert_equal [:app_method_missing, false, [1], {}, nil], toggle.value(1)
      assert_equal [:app_method_missing, false, [], { upcase: true }, nil], toggle.value(upcase: true)
      assert_equal [:app_method_missing, false, [], {}, :block], toggle.value { :block }
      assert_equal [:app_method_missing, false, [1], { upcase: true }, :block], toggle.value(1, upcase: true) { :block }
    end
    with_app_methods(Ruflet::Control, "def method_missing(name, *args, **options, &block) = super") do
      error = assert_raises(NoMethodError) { toggle.value }
      assert_equal :value, error.name
    end
    assert_equal false, toggle.value
  end

  # An app with its own method_missing that also has a private or protected
  # method of that name above the table class (a top-level helper, say). On
  # main, CRuby sent `control.value` to the method_missing: a call with a
  # receiver cannot reach a private or protected method. It still does, with
  # the arguments, keyword arguments and block. A public method there still
  # comes first, as it did on main.
  def test_an_app_method_missing_still_wins_over_private_and_protected_methods
    toggle = Ruflet.switch(label: "Dark mode", value: false)
    missing = <<~RUBY
      def method_missing(name, *args, **options, &block)
        name == :value ? [:app_method_missing, props["value"], args, options, block&.call] : super
      end
    RUBY
    answered = [:app_method_missing, false, [], {}, nil]

    with_app_methods(Ruflet::Control, missing) do
      with_app_methods(Object, "private def value(*, **) = :top_level_helper") do
        assert_equal answered, toggle.value
        assert_equal [:app_method_missing, false, [1], { upcase: true }, :block], toggle.value(1, upcase: true) { :block }
        assert_equal answered, toggle.public_send(:value)
        # The known difference (see the module comment): main reached the
        # helper from these, which the reader cannot tell from a call with
        # a receiver.
        assert_equal answered, toggle.instance_eval { value }
        assert_equal answered, toggle.instance_eval { self.value }
        assert_equal answered, toggle.send(:value)
      end
      with_app_methods(Ruflet::Control, <<~RUBY) do
        protected def value = :protected_app_method
        def peek(other) = other.value
      RUBY
        assert_equal answered, toggle.value
        # The known difference for a protected method: main reached it from
        # another control.
        assert_equal answered, Ruflet.switch(value: true).peek(toggle)
      end
      # What decides is the first method after the reader, as in Ruby's own
      # lookup: TextInputMethods comes before Object.
      field = Ruflet.text_field(label: "Name", value: "Ada")
      with_app_methods(Ruflet::UI::Controls::TextInputMethods, "private def value = :text_input") do
        assert_equal [:app_method_missing, "Ada", [], {}, nil], field.value
        with_app_methods(Object, "def value = :public_object_method") do
          assert_equal [:app_method_missing, "Ada", [], {}, nil], field.value
        end
      end
      with_app_methods(Object, "def value = :public_object_method") do
        assert_equal :public_object_method, toggle.value
        # On the superclass chain too: a private or protected
        # Ruflet::Control#value hides the public Object#value, and so does a
        # bare visibility change there. (mruby's public_method_defined? on
        # Ruflet::Control did not see that.)
        with_app_methods(Ruflet::Control, "private def value = :private_control_method") do
          assert_equal answered, toggle.value
        end
        with_app_methods(Ruflet::Control, "protected def value = :protected_control_method") do
          assert_equal answered, toggle.value
        end
        with_app_methods(Ruflet::Control, "private :value") do
          assert_equal answered, toggle.value
          # The known difference again: main reached Object#value from here.
          assert_equal answered, toggle.instance_eval { value }
        end
        assert_equal :public_object_method, toggle.value
      end
      # And a public Ruflet::Control#value hides a private Object#value.
      with_app_methods(Object, "private def value = :top_level_helper") do
        with_app_methods(Ruflet::Control, "def value = :public_control_method") do
          assert_equal :public_control_method, toggle.value
        end
      end
      assert_equal answered, toggle.value
    end
    assert_equal false, toggle.value
  end

  # The same in a real script: its own method_missing on Ruflet::Control and
  # a top-level helper of the same name. Main printed true and left no
  # instance variable on the chip.
  def test_a_script_method_missing_still_wins_over_its_top_level_helper
    out = run_ruby(<<~RUBY)
      require "ruflet"
      class Ruflet::Control
        def method_missing(name, *args, &block)
          return props[name.to_s] if args.empty? && block.nil? && props.key?(name.to_s)

          super
        end
      end
      def selected = (@selected ||= [])
      chip = Ruflet.chip(label: Ruflet.text("Tag"), selected: true)
      print [chip.selected, chip.instance_variable_defined?(:@selected), selected].inspect
    RUBY

    assert_equal "[true, false, []]", out
  end

  # An extension registered after Ruflet loads gets a private Kernel DSL
  # helper. One named like a reader (Flutter's Expanded, say) is Ruflet's
  # helper, not an app method: a plain `tile.expanded` returns the tile's
  # state and builds nothing (main raised "private method 'expanded'
  # called"). Calls with arguments or a block still reach the helper, an app
  # method_missing still answers, and so does an app's own Kernel#expanded.
  def test_an_extension_helper_named_like_a_reader_does_not_answer_plain_reads
    out = run_ruby(<<~RUBY)
      require "ruflet"
      class ExpandedControl < Ruflet::Control
        def initialize(**props) = super(type: "expanded", **props)
      end
      Ruflet::Extensions.register_control(:expanded, control_class: ExpandedControl)
      roots = -> { Ruflet::DSL._pending_app.instance_variable_get(:@roots).map(&:type) }
      results = []

      tile = Ruflet.expansion_tile(title: Ruflet.text("More"), expanded: true)
      results << tile.expanded << tile.public_send(:expanded) << roots.call
      column = Ruflet.column do
        inner = expansion_tile(title: text("x"), expanded: false)
        results << inner.expanded
      end
      results << column.children.map(&:type) << roots.call
      # Known difference: a plain call without a receiver from inside the tile
      # built an empty `expanded` control on main.
      results << tile.instance_eval { expanded }

      # With arguments or a block, the helper still builds the control.
      class Ruflet::UI::Controls::RufletComponents::ExpansionTileControl
        def body_from_args = expanded(content: Ruflet.text("body"))
        def body_from_block = expanded { nil }
      end
      results << tile.body_from_args.type << tile.body_from_block.type
      results << expanded(content: text("top")).type

      other = Ruflet.expansion_tile(title: Ruflet.text("x"), expanded: true)
      def other.method_missing(name, *args, **options, &block)
        name == :expanded ? :object_method_missing : super
      end
      results << other.expanded

      # With an app method_missing, the calls from inside the tile go to it
      # (the "Not covered" case: main built a control for both), and so does
      # tile.expanded, as on main.
      class Ruflet::Control
        def method_missing(name, *args, **options, &block)
          name == :expanded ? :control_method_missing : super
        end
      end
      results << tile.instance_eval { expanded } << tile.body_from_args << tile.expanded
      Ruflet::Control.send(:remove_method, :method_missing)

      # App methods of that name still answer: a top-level helper (a private
      # Object method, before Kernel), and the app's own Kernel#expanded.
      def expanded(**) = :top_level_helper
      results << tile.instance_eval { expanded } << tile.expanded
      Object.send(:remove_method, :expanded)
      module Kernel
        private def expanded(**) = :app_kernel_method
      end
      results << tile.instance_eval { expanded } << tile.expanded

      # A module the table class includes comes before Kernel too:
      # TextFieldControl includes TextInputMethods.
      class SelectionControl < Ruflet::Control
        def initialize(**props) = super(type: "selection", **props)
      end
      Ruflet::Extensions.register_control(:selection, control_class: SelectionControl)
      field = Ruflet.text_field(label: "Name", value: "Ada")
      results << field.selection
      Ruflet::UI::Controls::TextInputMethods.module_eval { def selection = :text_input_method }
      results << field.selection
      print results.inspect
    RUBY

    assert_equal '[true, true, [], false, ["expansiontile"], [], true, ' \
                 '"expanded", "expanded", "expanded", :object_method_missing, ' \
                 ":control_method_missing, :control_method_missing, :control_method_missing, " \
                 ":top_level_helper, :top_level_helper, :app_kernel_method, :app_kernel_method, " \
                 "nil, :text_input_method]", out
  end

  # register_control's Kernel helper is a visibility change: Kernel makes the
  # SharedControlForwarders method private. Ruby 3.1 and earlier report the
  # module that defined such a method as its UnboundMethod#owner, where Ruby
  # 3.2 and later report Kernel (Ruby bug #18729). The script makes #owner
  # answer as on 3.1, and the plain read still returns the tile's state.
  def test_the_extension_helper_check_does_not_depend_on_unbound_method_owner
    out = run_ruby(<<~RUBY)
      require "ruflet"
      class ExpandedControl < Ruflet::Control
        def initialize(**props) = super(type: "expanded", **props)
      end
      Ruflet::Extensions.register_control(:expanded, control_class: ExpandedControl)
      forwarders = Ruflet::UI::SharedControlForwarders
      UnboundMethod.prepend(Module.new do
        define_method(:owner) do
          real = super()
          real.equal?(Kernel) && name == :expanded ? forwarders : real
        end
      end)
      tile_class = Ruflet::UI::Controls::RufletComponents::ExpansionTileControl
      owners = [Kernel.instance_method(:expanded).owner, tile_class.superclass.instance_method(:expanded).owner]
      tile = Ruflet.expansion_tile(title: Ruflet.text("More"), expanded: true)
      value = tile.expanded
      print [owners, value, Ruflet::DSL._pending_app.instance_variable_get(:@roots).map(&:type)].inspect
    RUBY

    assert_equal "[[Ruflet::UI::SharedControlForwarders, Ruflet::UI::SharedControlForwarders], true, []]", out
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
