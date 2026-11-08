# frozen_string_literal: true

require_relative "test_helper"

# Loading ruflet_core puts the bare DSL helpers on Kernel, so every object in
# the process has them — a Rails app that loads Ruflet included. v0.0.23 fixed
# that set; a helper added to it later wins over any other library's
# method_missing builder with the same tag name, and code that is not Ruflet's
# changes behaviour (Nokogiri::HTML::Builder.new { table { ... } } built a
# Ruflet Table instead of a <table>).
#
# Helpers added after v0.0.23 are reached through Kernel#method_missing
# instead, which every builder with its own method_missing takes precedence
# over, and only by calls a private Kernel method would have answered: ones
# without an explicit receiver, with or without arguments.
class KernelHelperShadowingTest < Minitest::Test
  LIB_ROOT = "#{File.expand_path('../lib', __dir__)}/".freeze
  V0_0_23_NAMES = File.readlines(File.expand_path("fixtures/kernel_helpers_v0_0_23.txt", __dir__), chomp: true)
                      .reject { |line| line.empty? || line.start_with?("#") }
                      .freeze

  NEW_HELPERS = %i[
    about_dialog aboutdialog carousel_view carouselview custom_scroll_view customscrollview
    draggable_scrollable_sheet draggablescrollablesheet fitted_box fittedbox form_row formrow
    indexed_stack indexedstack list_section listsection sliver_app_bar sliverappbar
    sliver_fill_remaining sliverfillremaining sliver_grid slivergrid sliver_list sliverlist
    sliver_to_box_adapter slivertoboxadapter stepper stepper_step stepperstep table table_row tablerow
  ].freeze

  # Stands in for Nokogiri::HTML::Builder, Builder::XmlMarkup, Jbuilder and
  # the like: every tag is a missing method.
  class TagBuilder
    attr_reader :tags

    def initialize
      @tags = []
    end

    def build(&block)
      instance_eval(&block)
      self
    end

    def method_missing(name, *_args, **_attrs, &block)
      @tags << name
      instance_eval(&block) if block
      self
    end

    def respond_to_missing?(_name, _include_private = false)
      true
    end
  end

  # A method_missing that handles some names and passes the rest up.
  class PartialMissing
    def method_missing(name, *args, &block)
      return :handled if name == :handled

      super
    end

    def respond_to_missing?(name, include_private = false)
      name == :handled || super
    end
  end

  def setup
    Ruflet::DSL._reset_pending_app!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  def test_loading_ruflet_adds_no_method_to_every_object_beyond_v0_0_23
    added = ruflet_methods_on_every_object - V0_0_23_NAMES - runtime_extension_helpers

    assert_empty added, "these became methods of every object in the process; add new helpers to " \
                        "Ruflet::UI::ScopedControlForwarders, not SharedControlForwarders/Kernel"
  end

  def test_every_v0_0_23_bare_helper_is_still_defined
    assert_empty V0_0_23_NAMES - ruflet_methods_on_every_object
  end

  def test_helpers_added_after_v0_0_23_are_not_methods_of_ordinary_objects
    object = Object.new

    NEW_HELPERS.each do |name|
      refute object.respond_to?(name, true), "Object.new.respond_to?(#{name.inspect}, true)"
      refute Kernel.private_method_defined?(name), "Kernel##{name} (private)"
      refute Kernel.method_defined?(name), "Kernel##{name}"
    end
  end

  def test_method_missing_forwards_exactly_the_scoped_helpers
    scoped = Ruflet::UI::ScopedControlForwarders

    assert_equal scoped.instance_methods(false).sort, scoped::HELPERS.keys.sort
    assert_empty NEW_HELPERS - scoped::HELPERS.keys
    assert_same TOPLEVEL_BINDING.receiver, scoped::SCRIPT_MAIN
  end

  def test_method_missing_builders_still_receive_the_new_names
    builder = TagBuilder.new.build do
      table(class: "grid") do
        table_row { form_row("x") }
        tablerow
      end
      stepper(current: 1) { stepper_step(title: "a") }
      about_dialog
      fitted_box("y")
      sliver_list([])
    end

    assert_equal %i[table table_row form_row tablerow stepper stepper_step about_dialog fitted_box sliver_list],
                 builder.tags

    # Every name, written as a bare word, with arguments and with a block.
    NEW_HELPERS.each do |name|
      tags = TagBuilder.new.instance_eval("build { #{name}; #{name}(1, a: 2); #{name} { } }", __FILE__, __LINE__)
                       .tags
      assert_equal [name, name, name], tags, name.to_s
    end
  end

  def test_nokogiri_builder_still_builds_a_table
    begin
      require "nokogiri"
    rescue LoadError
      skip "nokogiri is not installed"
    end

    doc = Nokogiri::HTML::Builder.new { table { tr { td "cell" } } }.doc

    refute_nil doc.root
    assert_equal "<table><tr><td>cell</td></tr></table>", doc.root.to_html.delete("\n")
  end

  # A private Kernel helper cannot be called with an explicit receiver, so
  # `record.table` raised NoMethodError on v0.0.23 and on main alike. That
  # holds on Ruflet's own objects too, where v0.0.23 built a generic control
  # only for a call with arguments.
  def test_explicit_receivers_raise_without_arguments
    receivers = [Object.new, nil, Class.new(Ruflet::App) { def view(_page) = nil }.new, PartialMissing.new,
                 Ruflet.text("x"), Ruflet.column([])]

    receivers.each do |receiver|
      %i[table about_dialog stepper fitted_box sliver_app_bar list_section].each do |name|
        error = assert_raises(NoMethodError, "#{receiver.class}##{name}") do
          eval("receiver.#{name}", binding, __FILE__, __LINE__)
        end
        assert_equal name, error.name
        refute error.private_call?
      end
    end

    zork = assert_raises(NoMethodError) { Ruflet.text("x").zork }
    assert_equal :zork, zork.name
  end

  def test_ruflet_owned_receivers_still_build_with_arguments_as_on_v0_0_23
    control = Ruflet.text("x")

    assert_kind_of Ruflet::Control, control.table(1)
    assert_kind_of Ruflet::Control, control.stepper { nil }
    assert_kind_of Ruflet::Control, control.zork(1)
  end

  # v0.0.23 did not have these names, so `record.table(1)` raised
  # NoMethodError. A private Kernel helper could not have been called that way
  # either; only a call without a receiver is a helper call.
  def test_explicit_receivers_raise_as_on_v0_0_23
    app = Class.new(Ruflet::App) { def view(_page) = nil }.new
    receivers = [Object.new, Struct.new(:n).new(1), nil, 1, app, PartialMissing.new]
    calls = {
      "stepper([1])" => ->(receiver) { receiver.stepper([1]) },
      "table(1)" => ->(receiver) { receiver.table(1) },
      "table(rows: [])" => ->(receiver) { receiver.table(rows: []) },
      "stepper { }" => ->(receiver) { receiver.stepper {} },
      "list_section([])" => ->(receiver) { receiver.list_section([]) },
      "public_send(:table, rows: [])" => ->(receiver) { receiver.public_send(:table, rows: []) }
    }

    receivers.each do |receiver|
      calls.each do |label, call|
        error = assert_raises(NoMethodError, "#{receiver.class}##{label}") { call.call(receiver) }
        assert_match(/undefined method .(stepper|table|list_section)'/, error.message)
        refute error.private_call?
      end
    end

    assert_raises(NoMethodError) { app.about_dialog }
    assert_raises(NoMethodError) { app.stepper([Ruflet.stepper_step(title: "A")]) }
  end

  def test_calls_without_a_receiver_still_build_in_ordinary_objects
    object = Object.new

    assert_equal "Table", object.instance_eval { table(rows: []) }.to_patch["_c"]
    assert_equal "Table", object.instance_eval { table([]) }.to_patch["_c"]
    assert_equal "Stepper", object.instance_eval { stepper { stepper_step(title: "A") } }.to_patch["_c"]
    assert_equal "Table", object.send(:table, rows: []).to_patch["_c"]
    assert_equal "FittedBox", PartialMissing.new.instance_eval { fitted_box(text("x")) }.to_patch["_c"]
    assert_equal :handled, PartialMissing.new.handled

    component = Class.new do
      def own = self.stepper([stepper_step(title: "A")])
      def in_block = [1].map { |index| sliver_list([text(index.to_s)]) }.first
    end

    assert_equal "Stepper", component.new.own.to_patch["_c"]
    assert_equal "SliverList", component.new.in_block.to_patch["_c"]
  end

  # Every helper v0.0.23 shipped is a private Kernel method, so a bare call
  # to it works with no arguments anywhere (`divider` in a component). The
  # newer ones answer the same calls: a bare word, `name()` and `self.name`,
  # in a plain object, a component, an app and a test alike, and build what
  # Ruflet::DSL.<name> builds (or raise what it raises, for a helper that
  # needs content).
  def test_bare_calls_without_arguments_work_wherever_a_v0_0_23_helper_does
    app = Class.new(Ruflet::App) { def view(_page) = nil }.new
    component = Class.new.new

    NEW_HELPERS.each do |name|
      expected = outcome { Ruflet::DSL.public_send(name) }

      [Object.new, component, app, self].each do |receiver|
        ["#{name}", "#{name}()", "self.#{name}"].each do |source|
          actual = outcome { receiver.instance_eval(source, __FILE__, __LINE__) }
          assert_equal expected, actual, "#{receiver.class}: #{source}"
        end
      end
    end

    assert_equal "AboutDialog", about_dialog.wire_type
    assert_equal "SliverAppBar", sliver_app_bar.wire_type
    assert_equal "Table", table.wire_type
  end

  # Ruflet::Extensions puts a registered helper on SharedControlForwarders;
  # an extension under one of the scoped names must win on Ruflet and
  # Ruflet::UI too (see extension_helper_collision_test.rb).
  def test_shared_forwarders_rank_above_scoped_forwarders
    shared = Ruflet::UI::SharedControlForwarders
    scoped = Ruflet::UI::ScopedControlForwarders

    [Ruflet, Ruflet::UI].each do |namespace|
      ancestors = namespace.singleton_class.ancestors
      assert_operator ancestors.index(shared), :<, ancestors.index(scoped), "#{namespace} lookup order"
    end
  end

  def test_bare_new_helpers_build_controls_inside_ruflet_run
    controls = run_at_top_level(<<~RUBY)
      Ruflet.run do |page|
        [
          stepper([stepper_step(title: "Account"), stepperstep(title: "Done")], current_step: 1),
          table([table_row([text("a"), text("b")]), tablerow([text("c"), text("d")])]),
          custom_scroll_view([sliver_app_bar(title: text("T")), sliver_list([text("i")]),
                              sliver_grid([text("g")]), sliver_to_box_adapter(text("box")),
                              sliver_fill_remaining(text("rest"))]),
          customscrollview([sliverappbar(title: text("T")), sliverlist([text("i")]), slivergrid([text("g")]),
                            slivertoboxadapter(text("box")), sliverfillremaining(text("rest"))]),
          fitted_box(text("fit")), fittedbox(text("fit")),
          form_row(text_field(label: "Name")), formrow(text_field(label: "Name")),
          indexed_stack([text("0"), text("1")], index: 1), indexedstack([text("0")]),
          list_section([text("s")]), listsection([text("s")]),
          carousel_view([text("c")]), carouselview([text("c")]),
          draggable_scrollable_sheet([text("d")]), draggablescrollablesheet([text("d")]),
          about_dialog(application_name: "App"), aboutdialog(application_name: "App"),
          about_dialog, sliver_app_bar
        ].each { |control| page.add(control) }
      end
    RUBY

    assert_equal %w[Stepper Table CustomScrollView CustomScrollView FittedBox FittedBox FormRow FormRow
                    IndexedStack IndexedStack ListSection ListSection CarouselView CarouselView
                    DraggableScrollableSheet DraggableScrollableSheet AboutDialog AboutDialog
                    AboutDialog SliverAppBar],
                 controls.map { |control| control.to_patch["_c"] }

    stepper, table, slivers = controls.first(3).map(&:to_patch)
    assert_equal %w[Step Step], stepper["steps"].map { |step| step["_c"] }
    assert_equal %w[Account Done], stepper["steps"].map { |step| step["title"] }
    assert_equal 1, stepper["current_step"]
    assert_equal %w[TableRow TableRow], table["rows"].map { |row| row["_c"] }
    assert_equal %w[SliverAppBar SliverList SliverGrid SliverToBoxAdapter SliverFillRemaining],
                 slivers["slivers"].map { |sliver| sliver["_c"] }
    assert_equal 1, controls[8].to_patch["index"]
  end

  def test_bare_new_helpers_match_the_explicit_ruflet_helpers
    bare = run_at_top_level(<<~RUBY)
      Ruflet.run do |_page|
        [stepper([stepper_step(title: "A")], current_step: 0, type: "horizontal"),
         table([table_row([text("x")])], border_width: 1, border_color: "#cccccc"),
         fitted_box(text("f"), fit: "contain")]
      end
    RUBY
    explicit = [
      Ruflet.stepper([Ruflet.stepper_step(title: "A")], current_step: 0, type: "horizontal"),
      Ruflet.table([Ruflet.table_row([Ruflet.text("x")])], border_width: 1, border_color: "#cccccc"),
      Ruflet.fitted_box(Ruflet.text("f"), fit: "contain")
    ]

    assert_equal explicit.map { |control| without_ids(control.to_patch) },
                 bare.map { |control| without_ids(control.to_patch) }
  end

  def test_bare_new_helpers_work_in_class_based_apps_and_components
    app_class = Class.new(Ruflet::App) do
      def view(page)
        page.add(about_dialog)
        page.add(stepper([stepper_step(title: "One")]))
        page.add(table([table_row([text("r")])]))
      end
    end
    page = new_page
    app_class.new.view(page)

    assert_equal %w[AboutDialog Stepper Table], page.controls.map { |control| control.to_patch["_c"] }

    component = Class.new do
      def build = list_section([text("item")], header: text("Section"))
      def dialog = about_dialog
      def app_bar = sliver_app_bar
    end

    assert_equal "ListSection", component.new.build.to_patch["_c"]
    assert_equal "AboutDialog", component.new.dialog.to_patch["_c"]
    assert_equal "SliverAppBar", component.new.app_bar.to_patch["_c"]
  end

  def test_ruflet_namespaces_and_builders_keep_the_new_helpers
    NEW_HELPERS.each do |name|
      assert_respond_to Ruflet, name
      assert_respond_to Ruflet::UI, name
      assert_respond_to Ruflet::DSL, name
      assert Ruflet::UI::ControlMethods.method_defined?(name), "ControlMethods##{name}"
    end

    assert_equal "Table", Ruflet.table([Ruflet.table_row([Ruflet.text("a")])]).to_patch["_c"]
    assert_equal "Stepper", Ruflet::UI.stepper([Ruflet.stepper_step(title: "A")]).to_patch["_c"]
    assert_equal "FormRow", Ruflet::WidgetBuilder.new.form_row(Ruflet.text("x")).to_patch["_c"]

    column = Ruflet.column { table([table_row([text("in block")])]) }
    assert_equal ["Table"], column.children.map { |child| child.to_patch["_c"] }

    app = Ruflet::DSL.app { stepper([stepper_step(title: "A")]) }
    assert_equal ["Stepper"], app.instance_variable_get(:@roots).map { |root| root.to_patch["_c"] }
  end

  private

  # Every method an arbitrary object gained from ruflet_core's own files.
  def ruflet_methods_on_every_object
    (Object.private_instance_methods + Object.instance_methods).uniq.filter_map do |name|
      location = Object.instance_method(name).source_location
      name.to_s if location && location.first.start_with?(LIB_ROOT)
    end
  end

  # Extensions an app registers at runtime get bare helpers by design.
  def runtime_extension_helpers
    Ruflet::Extensions.each.flat_map(&:helpers)
  end

  # The class and wire type a call returns, or the error it raises.
  def outcome
    value = yield
    [value.class, value.respond_to?(:wire_type) ? value.wire_type : nil]
  rescue StandardError => e
    [e.class, e.message]
  end

  def run_at_top_level(source)
    page = new_page
    interceptor = ->(entrypoint:, **) { entrypoint.call(page) }
    Ruflet.with_run_interceptor(interceptor) { TOPLEVEL_BINDING.eval(source) }
  end

  def new_page
    Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})
  end

  def without_ids(value)
    case value
    when Hash then value.reject { |key, _| key == "_i" || key == "id" }.transform_values { |v| without_ids(v) }
    when Array then value.map { |v| without_ids(v) }
    else value
    end
  end
end
