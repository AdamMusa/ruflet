# frozen_string_literal: true

require_relative "test_helper"

# Loading ruflet_core puts the bare DSL helpers on Kernel, so every object in
# the process has them — a Rails app that loads Ruflet included. v0.0.23 fixed
# that set; a helper added to it later wins over any other library's
# method_missing builder with the same tag name, and code that is not Ruflet's
# changes behaviour (Nokogiri::HTML::Builder.new { table { ... } } built a
# Ruflet Table instead of a <table>, and `form(action: "/x") { ... }` raised).
#
# Helpers added after v0.0.23 are reached through Kernel#method_missing
# instead, which every builder with its own method_missing takes precedence
# over, and only by calls a private Kernel method would have answered (ones
# without an explicit receiver, with or without arguments) or that v0.0.23
# already built a control for (with arguments, at a script's top level or on
# a Ruflet object).
class KernelHelperShadowingTest < Minitest::Test
  LIB_ROOT = "#{File.expand_path('../lib', __dir__)}/".freeze
  V0_0_23_NAMES = File.readlines(File.expand_path("fixtures/kernel_helpers_v0_0_23.txt", __dir__), chomp: true)
                      .reject { |line| line.empty? || line.start_with?("#") }
                      .freeze

  # Every bare helper added since v0.0.23, the layout, clip, transition, form
  # and nested-scroll controls and the local_authentication service of #72
  # included.
  NEW_HELPERS = %i[
    about_dialog aboutdialog absorb_pointer absorbpointer carousel_view carouselview clip_oval clipoval
    clip_rsuperellipse cliprsuperellipse custom_scroll_view customscrollview draggable_scrollable_sheet
    draggablescrollablesheet fade_transition fadetransition fitted_box fittedbox form form_row formrow
    fractionally_sized_box fractionallysizedbox ignore_pointer ignorepointer indexed_stack indexedstack
    intrinsic_height intrinsicheight intrinsic_width intrinsicwidth list_section listsection local_auth
    local_authentication nested_scroll_view nestedscrollview rotation_transition rotationtransition
    scale_transition scaletransition size_transition sizetransition slide_transition slidetransition
    sliver_app_bar sliverappbar sliver_fill_remaining sliverfillremaining sliver_grid slivergrid sliver_list
    sliverlist sliver_padding sliverpadding sliver_to_box_adapter slivertoboxadapter stepper stepper_step
    stepperstep table table_row tablerow
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

    later = TagBuilder.new.build do
      form(action: "/x") { ignore_pointer }
      fade_transition
      local_auth
    end
    assert_equal %i[form ignore_pointer fade_transition local_auth], later.tags

    # Every name, written as a bare word, with arguments and with a block.
    NEW_HELPERS.each do |name|
      tags = TagBuilder.new.instance_eval("build { #{name}; #{name}(1, a: 2); #{name} { } }", __FILE__, __LINE__)
                       .tags
      assert_equal [name, name, name], tags, name.to_s
    end
  end

  def test_nokogiri_builder_still_builds_a_table_and_a_form
    begin
      require "nokogiri"
    rescue LoadError
      skip "nokogiri is not installed"
    end

    doc = Nokogiri::HTML::Builder.new { table { tr { td "cell" } } }.doc

    refute_nil doc.root
    assert_equal "<table><tr><td>cell</td></tr></table>", doc.root.to_html.delete("\n")

    form = Nokogiri::HTML::Builder.new { form(action: "/x") { input(type: "text") } }.doc

    refute_nil form.root
    assert_equal '<form action="/x"><input type="text"></form>', form.root.to_html.delete("\n")
  end

  # A private Kernel helper cannot be called with an explicit receiver, so
  # `record.table` raised NoMethodError on v0.0.23 and on main alike. That
  # holds on Ruflet's own objects too, where v0.0.23 built a generic control
  # only for a call with arguments.
  def test_explicit_receivers_raise_without_arguments
    receivers = [Object.new, nil, Class.new(Ruflet::App) { def view(_page) = nil }.new, PartialMissing.new,
                 Ruflet.text("x"), Ruflet.column([]), TOPLEVEL_BINDING.receiver]

    receivers.each do |receiver|
      %i[table about_dialog stepper form ignore_pointer fade_transition local_auth].each do |name|
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

  def test_ruflet_owned_receivers_still_build_with_arguments_or_a_block_as_on_v0_0_23
    control = Ruflet.text("x")

    assert_kind_of Ruflet::Control, control.table(1)
    assert_kind_of Ruflet::Control, control.form(controls: [])
    assert_kind_of Ruflet::Control, control.zork(1)

    # So are a script's top-level object, named or not, and a page.
    assert_kind_of Ruflet::Control, TOPLEVEL_BINDING.receiver.table(rows: [])
    assert_kind_of Ruflet::Control, new_page.stepper(current_step: 1)

    # A block alone is enough: v0.0.23 built a generic control for
    # `Ruflet.text("x").table { }` too, and these build the real one.
    event = Ruflet::Event.new(name: "click", target: 1, raw_data: nil, page: nil, control: nil)
    assert_equal without_ids(Ruflet::DSL.table {}.to_patch), without_ids(control.table {}.to_patch)
    assert_equal without_ids(Ruflet::DSL.stepper {}.to_patch), without_ids(event.stepper {}.to_patch)
    assert_equal without_ids(Ruflet::DSL.form { Ruflet.text_field(label: "N") }.to_patch),
                 without_ids(TOPLEVEL_BINDING.receiver.form { Ruflet.text_field(label: "N") }.to_patch)
    assert_equal "Form", TOPLEVEL_BINDING.receiver.form { Ruflet.text_field(label: "N") }.wire_type
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
      "public_send(:table, rows: [])" => ->(receiver) { receiver.public_send(:table, rows: []) },
      "form(action: \"/x\")" => ->(receiver) { receiver.form(action: "/x") },
      "form { }" => ->(receiver) { receiver.form {} },
      "ignore_pointer(1)" => ->(receiver) { receiver.ignore_pointer(1) },
      "local_auth(key: \"k\")" => ->(receiver) { receiver.local_auth(key: "k") }
    }

    receivers.each do |receiver|
      calls.each do |label, call|
        error = assert_raises(NoMethodError, "#{receiver.class}##{label}") { call.call(receiver) }
        assert_match(/undefined method .(stepper|table|list_section|form|ignore_pointer|local_auth)'/, error.message)
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
      def form_with_fields = form { text_field(label: "Name") }
    end

    assert_equal "Stepper", component.new.own.to_patch["_c"]
    assert_equal "SliverList", component.new.in_block.to_patch["_c"]
    assert_equal "Form", component.new.form_with_fields.to_patch["_c"]
  end

  # Apps wrap helpers: `def section(*args, **opts, &block) = list_section(*args, **opts, &block)`.
  # A call forwarded with a positional splat, keywords, a block or `...` builds
  # what the direct Ruflet::DSL call builds, keywords included. (The embedded
  # VM's mruby 449627d drops such keywords before any method_missing runs;
  # tools/embedded_vm_harness/tests/scoped_helper_test.rb checks it there.)
  def test_forwarded_calls_build_what_the_direct_call_builds
    wrapper = Class.new
    NEW_HELPERS.each do |name|
      wrapper.class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        def splat_#{name}(*args, **props, &block) = #{name}(*args, **props, &block)
        def literal_#{name}(*args) = #{name}(*args, key: "lit")
        def dots_#{name}(...) = #{name}(...)
      RUBY
    end
    host = wrapper.new
    shapes = {
      "(key: \"k\")" => [[], { key: "k" }, nil],
      "([], key: \"k\")" => [[[]], { key: "k" }, nil],
      "(text, key: \"k\")" => [[Ruflet.text("c")], { key: "k" }, nil],
      "(key: \"k\") { }" => [[], { key: "k" }, proc {}]
    }

    NEW_HELPERS.each do |name|
      takes_block = Ruflet::DSL.method(name).parameters.any? { |type, _| type == :block }
      shapes.each do |label, (args, props, block)|
        next if block && !takes_block

        want = patch_or_error { Ruflet::DSL.public_send(name, *args, **props, &block) }
        %w[splat dots].each do |form|
          got = patch_or_error { host.public_send("#{form}_#{name}", *args, **props, &block) }
          assert_equal want, got, "#{form}_#{name}#{label}"
        end
        literal = patch_or_error { Ruflet::DSL.public_send(name, *args, key: "lit") }
        assert_equal literal, patch_or_error { host.public_send("literal_#{name}", *args) }, "literal_#{name}#{label}"
      end
    end
    assert_equal "k", host.splat_stepper([Ruflet.stepper_step(title: "A")], key: "k", current_step: 1).to_patch["key"]
    assert_equal 1, host.dots_stepper(current_step: 1).to_patch["current_step"]
  end

  # Kernel#method_missing reads a trailing Hash of Symbol keys, when no
  # keywords were passed, as the keywords. Keywords arrive that way from a
  # method_missing written without keywords that calls super (a user class,
  # Ruflet::Page, Ruflet::Event, a Ruflet::* class of an extension gem), and
  # from send, __send__ and public_send on the embedded VM. Each call builds
  # what Ruflet::DSL builds from the same keywords, as the Kernel method did
  # on main; explicit receivers outside Ruflet still raise.
  def test_keywords_that_arrive_as_a_trailing_hash_are_keywords
    # [bare call; a send whose arguments match what the embedded VM's send
    #  hands method_missing for that call; the control both must build]
    calls = [
      ['stepper(current_step: 1, type: "horizontal")', 'send(:stepper, { current_step: 1, type: "horizontal" })',
       -> { Ruflet::DSL.stepper(current_step: 1, type: "horizontal") }],
      ['stepper([stepper_step(title: "A")], current_step: 0)',
       'send(:stepper, [stepper_step(title: "A")], { current_step: 0 })',
       -> { Ruflet::DSL.stepper([Ruflet::DSL.stepper_step(title: "A")], current_step: 0) }],
      ['table(rows: [table_row([text("r")])], border_width: 1)',
       'send(:table, { rows: [table_row([text("r")])], border_width: 1 })',
       -> { Ruflet::DSL.table(rows: [Ruflet::DSL.table_row([Ruflet::DSL.text("r")])], border_width: 1) }],
      ['about_dialog(application_name: "App")', 'send(:about_dialog, { application_name: "App" })',
       -> { Ruflet::DSL.about_dialog(application_name: "App") }],
      ['local_auth(key: "auth")', 'send(:local_auth, { key: "auth" })', -> { Ruflet::DSL.local_auth(key: "auth") }],
      ['fade_transition(text("f"), repeat: true)', 'send(:fade_transition, text("f"), { repeat: true })',
       -> { Ruflet::DSL.fade_transition(Ruflet::DSL.text("f"), repeat: true) }],
      ['form([text_field(label: "Name")])', 'send(:form, [text_field(label: "Name")])',
       -> { Ruflet::DSL.form([Ruflet::DSL.text_field(label: "Name")]) }]
    ]
    keywordless = Class.new(PartialMissing)
    ruflet_class = Class.new(PartialMissing) { def self.name = "Ruflet::ExtensionGemHost" }
    event = Ruflet::Event.new(name: "click", target: 1, raw_data: nil, page: nil, control: nil)
    hosts = { "user class" => keywordless.new, "Ruflet::* class" => ruflet_class.new, "Ruflet::Event" => event,
              "Ruflet::Page" => new_page }

    calls.each do |source, vm_send, expected|
      want = without_ids(expected.call.to_patch)
      hosts.each do |label, host|
        assert_equal want, without_ids(host.instance_eval(source, __FILE__, __LINE__).to_patch), "#{label}: #{source}"
      end
      [vm_send, vm_send.sub("send", "__send__"), "TOPLEVEL_BINDING.receiver.#{vm_send}"].each do |call|
        assert_equal want, without_ids(Object.new.instance_eval(call, __FILE__, __LINE__).to_patch), call
      end
    end
    assert_equal :handled, keywordless.new.handled

    # Explicit receivers: still a NoMethodError outside Ruflet; on a Ruflet
    # object a call with arguments builds, as v0.0.23 built a control there.
    error = assert_raises(NoMethodError) { keywordless.new.stepper(current_step: 1) }
    assert_equal :stepper, error.name
    refute error.private_call?
    assert_raises(NoMethodError) { ruflet_class.new.about_dialog }
    assert_equal without_ids(Ruflet::DSL.stepper(current_step: 1).to_patch),
                 without_ids(event.stepper(current_step: 1).to_patch)
    assert_equal without_ids(Ruflet::DSL.about_dialog(application_name: "A").to_patch),
                 without_ids(ruflet_class.new.about_dialog(application_name: "A").to_patch)
  end

  # Only a non-empty Hash of Symbol keys, with no keywords beside it, is
  # read that way; any other Hash is passed on as written.
  def test_other_trailing_hashes_are_passed_as_written
    plain = Object.new

    assert_equal without_ids(Ruflet::DSL.table({ "rows" => [] }).to_patch),
                 without_ids(plain.instance_eval { table({ "rows" => [] }) }.to_patch)
    assert_equal({ "rows" => [] }, plain.instance_eval { table({ "rows" => [] }) }.to_patch["rows"])
    error = assert_raises(ArgumentError) { plain.instance_eval { about_dialog({ "application_name" => "App" }) } }
    assert_match(/wrong number of arguments/, error.message)
    assert_equal without_ids(Ruflet::DSL.fade_transition({ a: 1 }, repeat: true).to_patch),
                 without_ids(plain.instance_eval { fade_transition({ a: 1 }, repeat: true) }.to_patch)
    assert_equal without_ids(Ruflet::DSL.table({}).to_patch), without_ids(plain.instance_eval { table({}) }.to_patch)
    assert_equal "AboutDialog", plain.instance_eval { about_dialog({ application_name: "App" }) }.wire_type

    # One non-Symbol key is enough to keep a Hash positional.
    mixed = { rows: [], "border_width" => 1 }
    assert_equal without_ids(Ruflet::DSL.table(mixed).to_patch), without_ids(plain.instance_eval { table(mixed) }.to_patch)
    assert_equal({ "rows" => [], "border_width" => 1 }, plain.instance_eval { table(mixed) }.to_patch["rows"])
  end

  # The embedded VM has no NoMethodError#private_call?. An explicit call
  # stops there before Kernel#method_missing ("private method called"), so a
  # call that reaches it on an object whose method_missing is Kernel's had
  # no receiver; one that came through another class's method_missing
  # re-raises. This runs that path on CRuby with a VM-like error.
  def test_without_private_call_a_call_that_reaches_kernel_directly_had_no_receiver
    scoped = Ruflet::UI::ScopedControlForwarders
    vm_error = lambda do |name|
      NoMethodError.new("undefined method '#{name}'", name).tap do |error|
        error.singleton_class.send(:undef_method, :private_call?)
      end
    end
    refute vm_error.call(:table).respond_to?(:private_call?)

    # Objects with a `method` of their own, like an HTTP request.
    request = Class.new { def method = "GET" }.new
    builder_request = Class.new(PartialMissing) { def method(*) = "GET" }.new
    bare_word = NameError.new("undefined local variable or method 'table'", :table)

    assert scoped.receiverless?(vm_error.call(:table), Object.new, :table)
    assert scoped.receiverless?(vm_error.call(:table), request, :table)
    refute scoped.receiverless?(vm_error.call(:table), PartialMissing.new, :table)
    refute scoped.receiverless?(vm_error.call(:table), builder_request, :table)
    refute scoped.receiverless?(vm_error.call(:other), Object.new, :table)
    assert scoped.receiverless?(bare_word, PartialMissing.new, :table)
    refute scoped.receiverless?(NameError.new("uninitialized constant Missing", :Missing), Object.new, :table)

    # When Kernel#method cannot look method_missing up on the receiver, the
    # call is taken as one that reached Kernel's directly: an explicit call
    # stops at the VM's visibility check, so what got here is a bare call or
    # send.
    opaque = Class.new { undef_method :method_missing }.new
    assert_raises(NameError) { Kernel.instance_method(:method).bind_call(opaque, :method_missing) }
    assert scoped.receiverless?(vm_error.call(:table), opaque, :table)
  end

  # `super` in Kernel#method_missing can reach a method_missing that another
  # library included into Kernel after Ruflet. A NameError that code raises
  # about some other name is its own error, so it propagates instead of
  # being taken for the helper's miss.
  def test_an_unrelated_name_error_behind_kernel_propagates
    output = run_child(<<~RUBY)
      module Kernel
        include(Module.new do
          def method_missing(name, *args, **props, &block)
            return super unless name == :table
            missing_helper_of_this_library
          end
        end)
      end
      begin
        Object.new.instance_eval { table(rows: []) }
        puts "built"
      rescue NameError => e
        puts "\#{e.class} \#{e.name}"
      end
      puts Object.new.instance_eval { stepper(current_step: 1) }.wire_type
    RUBY

    assert_equal ["NameError missing_helper_of_this_library", "Stepper"], output
  end

  # Ruflet::Page answers the v0.0.23 helpers called on it with a "free
  # widget helper" hint. The newer names are left to Kernel#method_missing,
  # as on v0.0.23 when they did not exist there.
  def test_page_leaves_the_new_helpers_to_kernel
    page = new_page

    assert_equal without_ids(Ruflet::DSL.stepper(current_step: 1).to_patch),
                 without_ids(page.instance_eval { stepper(current_step: 1) }.to_patch)
    assert_equal "AboutDialog", page.instance_eval { about_dialog }.wire_type
    assert_equal "Table", page.table(rows: []).wire_type
    assert_raises(NoMethodError) { page.about_dialog }
    refute page.respond_to?(:stepper)
    page.stepper = 2
    assert_equal 2, page.stepper

    hint = assert_raises(NoMethodError) { page.text("x") }
    assert_match(/free widget helper/, hint.message)
    assert page.respond_to?(:text)
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

    assert_equal "IgnorePointer", ignore_pointer.wire_type
    assert_equal "FadeTransition", fade_transition.wire_type
    assert_equal "AboutDialog", about_dialog.wire_type
    assert_equal "LocalAuthentication", local_auth.wire_type
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

  def test_bare_layout_transition_form_and_service_helpers_build_inside_ruflet_run
    sources = {
      "absorb_pointer(text(\"a\"))" => "AbsorbPointer", "absorbpointer" => "AbsorbPointer",
      "fractionally_sized_box(text(\"f\"), width_factor: 0.5)" => "FractionallySizedBox",
      "fractionallysizedbox" => "FractionallySizedBox",
      "ignore_pointer(text(\"i\"))" => "IgnorePointer", "ignorepointer" => "IgnorePointer",
      "intrinsic_height(row([text(\"r\")]))" => "IntrinsicHeight", "intrinsicheight" => "IntrinsicHeight",
      "intrinsic_width(column([text(\"c\")]), step_width: 8)" => "IntrinsicWidth", "intrinsicwidth" => "IntrinsicWidth",
      "custom_scroll_view([sliver_padding([sliver_list([text(\"s\")])], padding: 4), sliverpadding])" =>
        "CustomScrollView",
      "clip_oval(text(\"o\"))" => "ClipOval", "clipoval" => "ClipOval",
      "clip_rsuperellipse(text(\"s\"), border_radius: 12)" => "ClipRSuperellipse",
      "cliprsuperellipse" => "ClipRSuperellipse",
      "fade_transition(text(\"f\"), repeat: true)" => "FadeTransition", "fadetransition" => "FadeTransition",
      "rotation_transition(icon(\"refresh\"))" => "RotationTransition", "rotationtransition" => "RotationTransition",
      "scale_transition(content: text(\"p\"), begin: 1, end: 1.1)" => "ScaleTransition",
      "scaletransition" => "ScaleTransition",
      "size_transition(text(\"s\"), axis: \"horizontal\")" => "SizeTransition", "sizetransition" => "SizeTransition",
      "slide_transition(text(\"s\"))" => "SlideTransition", "slidetransition" => "SlideTransition",
      "form([text_field(label: \"Name\")])" => "Form", "form { text_field(label: \"Email\") }" => "Form",
      "form" => "Form",
      "nested_scroll_view([sliver_app_bar(title: text(\"T\"))], body: list_view([text(\"b\")]))" => "NestedScrollView",
      "nestedscrollview(body: column([text(\"b\")]))" => "NestedScrollView"
    }
    controls = run_at_top_level(<<~RUBY)
      Ruflet.run do |page|
        [#{sources.keys.join(",\n ")}].each { |control| page.add(control) }
      end
    RUBY

    assert_equal sources.values, controls.map { |control| control.to_patch["_c"] }
    patch_of = ->(source) { controls[sources.keys.index(source)].to_patch }
    slivers = patch_of.call(sources.keys.grep(/\Acustom_scroll_view/).first)["slivers"]
    assert_equal %w[SliverPadding SliverPadding], slivers.map { |sliver| sliver["_c"] }
    assert_equal 0.5, patch_of.call(sources.keys.grep(/\Afractionally_sized_box/).first)["width_factor"]

    services = run_at_top_level(<<~RUBY)
      Ruflet.run { |_page| [local_auth, local_authentication(key: "auth")] }
    RUBY
    assert_equal %w[LocalAuthentication LocalAuthentication], services.map(&:wire_type)
    assert_equal "auth", services.last.to_patch["key"]
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
      def blocker = ignore_pointer
      def auth = local_auth
    end

    assert_equal "ListSection", component.new.build.to_patch["_c"]
    assert_equal "IgnorePointer", component.new.blocker.to_patch["_c"]
    assert_equal "LocalAuthentication", component.new.auth.wire_type
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

  # A call's patch without ids, or the error it raises.
  def patch_or_error
    without_ids(yield.to_patch)
  rescue StandardError => e
    [e.class, e.message]
  end

  def run_at_top_level(source)
    page = new_page
    interceptor = ->(entrypoint:, **) { entrypoint.call(page) }
    Ruflet.with_run_interceptor(interceptor) { TOPLEVEL_BINDING.eval(source) }
  end

  # Runs Ruby with ruflet_core loaded in a child process, for changes that
  # must not reach the rest of the suite; returns its output lines.
  def run_child(body)
    script = "$LOAD_PATH.unshift #{File.expand_path('../lib', __dir__).inspect}\nrequire \"ruflet_core\"\n#{body}"
    output = IO.popen([RbConfig.ruby, "-e", script], err: %i[child out], &:read)
    assert $?.success?, output
    output.lines(chomp: true)
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
