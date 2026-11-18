# Client-state readers (event.control.value, field.value) in the embedded VM.
#
# The readers must be the same methods on CRuby and in mruby. Build the VM
# archive from the current framework sources (tools/build_vm_artifacts.sh
# macos, or RUFLET_VM_LIBRARY pointing at a fresh build; the prebuilt
# ruby_runtime/macos archive carries an older framework), then:
#
#   tools/embedded_vm_harness/build.sh
#   tools/embedded_vm_harness/build/embedded_mruby --preload \
#     tools/embedded_vm_harness/tests/client_state_readers_test.rb
#
# The same file runs on CRuby:
#
#   ruby -I packages/ruflet_core/lib tools/embedded_vm_harness/tests/client_state_readers_test.rb
#
# Keep this file valid mruby (no defined?, no Regexp literals).
require "ruflet"

$failures = []
$tests = 0

def assert_equal(expected, actual, label)
  $tests += 1
  return if expected == actual

  $failures << "#{label}: expected #{expected.inspect}, got #{actual.inspect}"
end

def assert(condition, label)
  $tests += 1
  $failures << label unless condition
end

def assert_raises(klass, label)
  $tests += 1
  yield
  $failures << "#{label}: nothing raised"
rescue Exception => e
  $failures << "#{label}: raised #{e.class} (#{e.message})" unless e.is_a?(klass)
end

readers = Ruflet::UI::ClientStateReaders

# -- The framework installed every reader when it loaded ---------------------
# Nothing in this file calls install!: these fail if the framework (ruflet_ui.rb
# in the VM's compiled blob) stopped running it.
assert(Ruflet.switch(value: false).respond_to?(:value), "the framework installed the readers")
assert_equal([], readers.skipped, "the framework ran install! and it skipped no reader")
count = 0
readers.table.each do |klass, names|
  module_name = "Ruflet::UI::ClientStateReaders::" + klass.name.split("::").last(2).join
  names.each do |name|
    count += 1
    public_reader = klass.public_method_defined?(name.to_sym)
    assert(public_reader, "#{klass}##{name} is defined and public")
    next unless public_reader

    owner = klass.instance_method(name.to_sym).owner
    assert_equal(module_name, owner.name, "#{klass}##{name} comes from its reader module")
    assert_equal(owner, klass.ancestors[1], "#{klass}: the reader module comes right after the class")
    assert(!klass.instance_methods(false).include?(name.to_sym), "#{klass} itself defines no #{name}")
  end
end
assert_equal(51, count, "reader count")
# The readers look for an app method with method_defined?, which counts
# private methods in mruby only; on CRuby they also ask private_method_defined?.
assert_equal(RUBY_ENGINE == "mruby", readers::METHOD_DEFINED_COUNTS_PRIVATE, "method_defined? visibility probe")
unless $failures.empty?
  puts "client_state_readers_test (#{RUBY_ENGINE}): the readers are not installed"
  $failures.first(5).each { |failure| puts "  #{failure}" }
  raise "client state readers not installed"
end

# -- Documented flows: update_control, then the event -------------------------
def build_page
  Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: lambda { |_a, _p| nil })
end

cases = [
  [Ruflet.switch(label: "Email notifications", value: true), "change", false],
  [Ruflet.slider(value: 40, min: 0, max: 100, divisions: 10), "change", 70.0],
  [Ruflet.dropdown(label: "Fruit", value: "apple", options: [
    Ruflet.dropdown_option(key: "apple", text: "Apple"),
    Ruflet.dropdown_option(key: "banana", text: "Banana")
  ]), "select", "banana"],
  [Ruflet.date_picker(value: "2026-01-15", first_date: "2026-01-01", last_date: "2026-12-31"),
   "change", "2026-02-01T00:00:00.000"],
  [Ruflet.time_picker(value: "09:30", help_text: "Pick a start time"), "change", "10:15"]
]
cases.each do |control, event_name, data|
  page = build_page
  observed = []
  control.on(event_name) { |event| observed << event.control.value }
  page.add(control)
  page.apply_client_update(control.wire_id, { "value" => data })
  page.dispatch_event(target: control.wire_id, name: event_name, data: data)
  assert_equal([data], observed, "#{control.type} handler reads event.control.value")
  assert_equal(data, control.value, "#{control.type}.value afterwards")
end

toggle = Ruflet.switch(label: "Dark mode", value: false)
assert_equal(false, toggle.value, "toggle.value at construction")
assert(toggle.respond_to?(:value), "respond_to?(:value)")
assert_equal(false, toggle.method(:value).call, "method(:value)")
assert_equal(false, toggle.public_send(:value), "public_send(:value)")

field = Ruflet.dropdown(label: "Size", options: [Ruflet.dropdown_option(key: "s", text: "Small")])
page = build_page
page.add(field)
assert_equal(nil, field.value, "field.value before a pick")
page.apply_client_update(field.wire_id, { "value" => "s" })
page.dispatch_event(target: field.wire_id, name: "select", data: "s")
assert_equal("s", field.value, "field.value after the user picks")

legacy = Ruflet.dropdown_m2(options: [Ruflet.dropdown_option(key: "s", text: "Small")])
page = build_page
page.add(legacy)
page.apply_client_update(legacy.wire_id, { "value" => "s" })
assert_equal("s", legacy.value, "dropdown_m2 value")

range = Ruflet.range_slider(start_value: 10, end_value: 80, min: 0, max: 100)
page = build_page
page.add(range)
page.apply_client_update(range.wire_id, { "start_value" => 20.0, "end_value" => 60.0 })
assert_equal([20.0, 60.0], [range.start_value, range.end_value], "range_slider start/end")

# -- Nothing else changed ------------------------------------------------------
error = nil
begin
  toggle.value(1)
rescue ArgumentError => e
  error = e
end
assert_equal("wrong number of arguments (given 1, expected 0)", error && error.message, "reader with an argument")
assert_raises(ArgumentError, "reader with a keyword") { toggle.value(label: "x") }
assert_equal(false, toggle.value { raise "a reader ignores its block" }, "reader ignores a block")
assert_raises(NoMethodError, "no setter") { toggle.value = true }
assert_raises(NoMethodError, "label has no reader") { toggle.label }
assert(!toggle.respond_to?(:label), "respond_to?(:label) stays false")
assert(!toggle.respond_to?(:value=), "respond_to?(:value=) stays false")
assert(!toggle.respond_to?(:on_change), "respond_to?(:on_change) stays false")
button = Ruflet.icon_button(icon: "add", selected: true)
assert_raises(NoMethodError, "icon_button selected has no reader") { button.selected }
assert(!button.respond_to?(:selected), "icon_button respond_to?(:selected) stays false")

# `open` and Dropdown `text` stay the private Kernel methods every object has.
# (mruby's respond_to? also counts private methods, CRuby's does not; either
# way a control answers exactly like a plain object.)
plain = Object.new
dialog = Ruflet.alert_dialog(title: Ruflet.text("Hi"), open: true)
assert_raises(NoMethodError, "dialog.open stays the private Kernel#open") { dialog.open }
assert_equal(plain.respond_to?(:open), dialog.respond_to?(:open), "dialog respond_to?(:open) unchanged")
dropdown = Ruflet.dropdown(label: "Size", text: "Small", options: [])
assert_raises(NoMethodError, "dropdown.text stays the private text helper") { dropdown.text }
assert_equal(plain.respond_to?(:text), dropdown.respond_to?(:text), "dropdown respond_to?(:text) unchanged")

recorder = Ruflet::UI::Services::RufletServicesComponents::AudioRecorderControl.new(data: 1)
%w[data key configuration].each do |name|
  assert(!recorder.respond_to?(name.to_sym), "audio_recorder respond_to?(:#{name}) stays false")
end

# The guard, on classes that do have such methods. mruby has no
# Module#private_method_defined?; its method_defined? counts private methods.
class GuardBase
  attr_reader :props

  def initialize(props)
    @props = props
  end

  def selected
    :inherited
  end
end

class GuardControl < GuardBase
  def value
    :public
  end

  def expanded
    :protected
  end
  protected :expanded

  def selection
    :private
  end
  private :selection
end

guard_names = %w[value expanded selection selected open entry_mode]
skipped = readers.define_readers([[GuardControl, guard_names]])
assert_equal(%w[value expanded selection selected open].map { |name| [GuardControl, name] }, skipped,
             "guard skips public, protected, private, inherited and Kernel methods")
guarded = GuardControl.new({ "value" => 1, "expanded" => 1, "selection" => 1, "selected" => 1, "open" => 1, "entry_mode" => "input" })
assert_equal(:public, guarded.value, "public method kept")
assert_equal(:protected, guarded.send(:expanded), "protected method kept")
assert_equal(:private, guarded.send(:selection), "private method kept")
assert_equal(:inherited, guarded.selected, "inherited method kept")
assert_raises(NoMethodError, "private Kernel#open kept") { guarded.open }
assert_equal("input", guarded.entry_mode, "reader defined where no method existed")
assert_equal(GuardControl.ancestors[1], GuardControl.instance_method(:entry_mode).owner,
             "the reader comes from a module included into the class")

stepper = Ruflet.stepper(steps: [])
assert_equal("stepper", stepper.type, "Control#type is not shadowed")
assert_equal([toggle], [[toggle]].flatten, "flatten")

generic = Ruflet::Control.new(type: "my_extension_widget", value: 3)
assert_raises(NoMethodError, "schema-less control has no reader") { generic.value }

# -- A method the app adds after loading still wins ---------------------------
# Apps on v0.0.23 could not read these, so some added a reader of their own.
# Each case gives what it gives without the readers.
dropdown = Ruflet.dropdown(label: "Size", options: [])
toggle = Ruflet.switch(label: "Dark mode", value: false)
tabs = Ruflet.tabs(selected_index: 1, length: 2, content: Ruflet.text("x"))
text_field = Ruflet.text_field(label: "Name", value: "Ada")

Ruflet::Control.class_eval do
  def value
    props["value"].nil? ? "(unset)" : props["value"]
  end
end
assert_equal("(unset)", dropdown.value, "Ruflet::Control#value added by the app")
assert_equal(false, toggle.value, "Ruflet::Control#value added by the app, value set")
Ruflet::Control.send(:remove_method, :value)
assert_equal(nil, dropdown.value, "the reader answers again once the app method is gone")

Ruflet::UI::PlatformControlContracts::Components::PlatformControl.class_eval do
  def value
    "platform"
  end
end
assert_equal("platform", toggle.value, "PlatformControl#value added by the app")
Ruflet::UI::PlatformControlContracts::Components::PlatformControl.send(:remove_method, :value)

Ruflet::UI::Controls::TextInputMethods.class_eval do
  def value
    "text input"
  end
end
assert_equal("text input", text_field.value, "TextInputMethods#value added by the app")
assert_equal(false, toggle.value, "a switch does not include TextInputMethods")
Ruflet::UI::Controls::TextInputMethods.send(:remove_method, :value)

Ruflet::Control.class_eval do
  def value(fallback = :none, upcase: false, &block)
    result = props.key?("value") ? props["value"] : fallback
    result = result.to_s.upcase if upcase
    block ? block.call(result) : result
  end
end
plain_toggle = Ruflet.switch(label: "Plain")
assert_equal(:none, plain_toggle.value, "app method, no arguments")
assert_equal("GIVEN", plain_toggle.value("given", upcase: true), "app method gets the arguments")
assert_equal([:none], plain_toggle.value { |result| [result] }, "app method gets the block")
Ruflet::Control.send(:remove_method, :value)

Ruflet::Control.class_eval do
  def value
    :private
  end
  private :value
end
assert_equal(:private, toggle.send(:value), "private app method still answers send")
assert_equal(:private, toggle.instance_eval { value }, "private app method still answers a call without a receiver")
assert_equal(:private, toggle.value, "private app method answers control.value")
Ruflet::Control.send(:remove_method, :value)

# The readers ask Kernel#method unbound, so an app Ruflet::Control#method
# changes nothing.
Ruflet::Control.class_eval do
  def method(*args)
    props["method"]
  end
end
assert_equal(false, toggle.value, "an app Ruflet::Control#method leaves the reader answering")
Ruflet::Control.send(:remove_method, :method)

Ruflet::Control.class_eval do
  def method_missing(name, *args, **options, &block)
    name == :value ? [:app_method_missing, props["value"], args, options, block ? block.call : nil] : super
  end
end
answered = [:app_method_missing, false, [], {}, nil]
assert_equal(answered, toggle.value, "app method_missing still answers")
assert_equal([:app_method_missing, false, [1], {}, nil], toggle.value(1), "app method_missing gets the arguments")
assert_equal([:app_method_missing, false, [], { upcase: true }, nil], toggle.value(upcase: true),
             "app method_missing gets the keyword arguments")
assert_equal([:app_method_missing, false, [], {}, :block], toggle.value { :block }, "app method_missing gets the block")
assert_equal([:app_method_missing, false, [1], { upcase: true }, :block], toggle.value(1, upcase: true) { :block },
             "app method_missing gets arguments, keyword arguments and block together")
# Kernel#method is used unbound, so an app Ruflet::Control#method (an HTTP-verb
# style property, say) leaves the app method_missing answering.
Ruflet::Control.class_eval do
  def method(*args)
    props["method"]
  end
end
assert_equal(answered, toggle.value, "an app Ruflet::Control#method leaves the app method_missing answering")
Ruflet::Control.send(:remove_method, :method)

# With a private or protected method of that name above the table class too
# (a top-level helper, say), `control.value` still goes to the method_missing,
# as CRuby sent it there without the reader. A public one still comes first.
Object.class_eval do
  def value(*args, **options)
    :top_level_helper
  end
  private :value
end
assert_equal(answered, toggle.value, "app method_missing wins over a private Object helper")
assert_equal([:app_method_missing, false, [1], { upcase: true }, :block], toggle.value(1, upcase: true) { :block },
             "app method_missing wins over a private Object helper, with arguments and block")
assert_equal(answered, toggle.public_send(:value), "app method_missing wins over a private Object helper (public_send)")
Object.send(:remove_method, :value)
Ruflet::Control.class_eval do
  def value
    :protected_app_method
  end
  protected :value
end
assert_equal(answered, toggle.value, "app method_missing wins over a protected Ruflet::Control#value")
Ruflet::Control.send(:remove_method, :value)
# A protected method of Object or Kernel is the exception: every caller is an
# Object, so CRuby let `control.value` reach it without the reader.
Object.class_eval do
  def value
    :protected_object_method
  end
  protected :value
end
assert_equal(:protected_object_method, toggle.value, "a protected Object#value still comes before the app method_missing")
Object.send(:remove_method, :value)
module Kernel
  def value
    :protected_kernel_method
  end
  protected :value
end
assert_equal(:protected_kernel_method, toggle.value, "a protected Kernel#value still comes before the app method_missing")
Kernel.send(:remove_method, :value)
# And in a module Object includes (a script's top-level `include` puts it
# there). The module stays included, empty, for the rest of the file.
module ProtectedObjectHelpers
  def value
    :protected_module_method
  end
  protected :value
end
Object.send(:include, ProtectedObjectHelpers)
assert_equal(:protected_module_method, toggle.value,
             "a protected value in a module Object includes still comes before the app method_missing")
ProtectedObjectHelpers.send(:remove_method, :value)
Object.class_eval do
  def value
    :public_object_method
  end
end
assert_equal(:public_object_method, toggle.value, "a public Object#value still comes before the app method_missing")
# What decides is the first method after the reader: TextInputMethods comes
# before Object in a text field's lookup.
Ruflet::UI::Controls::TextInputMethods.class_eval do
  def value
    :text_input
  end
  private :value
end
assert_equal([:app_method_missing, "Ada", [], {}, nil], text_field.value,
             "a private TextInputMethods#value ahead of a public Object#value still sends the call to method_missing")
Ruflet::UI::Controls::TextInputMethods.send(:remove_method, :value)
# On the superclass chain too: a private or protected Ruflet::Control#value
# hides the public Object#value, and so does a bare visibility change there.
# (mruby's public_method_defined? on Ruflet::Control did not see that.)
Ruflet::Control.class_eval do
  def value
    :private_control_method
  end
  private :value
end
assert_equal(answered, toggle.value, "a private Ruflet::Control#value hides a public Object#value")
Ruflet::Control.send(:protected, :value)
assert_equal(answered, toggle.value, "a protected Ruflet::Control#value hides a public Object#value")
Ruflet::Control.send(:remove_method, :value)
Ruflet::Control.send(:private, :value)
assert_equal(answered, toggle.value, "private :value on Ruflet::Control hides a public Object#value")
Ruflet::Control.send(:remove_method, :value)
assert_equal(:public_object_method, toggle.value, "the public Object#value answers again")
Object.send(:remove_method, :value)
# And a public Ruflet::Control#value hides a private Object#value.
Object.class_eval do
  def value
    :top_level_helper
  end
  private :value
end
Ruflet::Control.class_eval do
  def value
    :public_control_method
  end
end
assert_equal(:public_control_method, toggle.value, "a public Ruflet::Control#value hides a private Object#value")
Ruflet::Control.send(:remove_method, :value)
Object.send(:remove_method, :value)
assert_equal(answered, toggle.value, "app method_missing answers again once the other methods are gone")

# When that method_missing passes a read on with super, the error is the one
# CRuby raised for the read without the reader, whatever missed earlier on the
# thread: NoMethodError "undefined method", or "private method ... called" /
# "protected method ... called" when such a method of that name sits after the
# reader. CRuby takes that from the thread's last miss, and the reader's own
# call to method_missing is none, so the reader repeats the miss first. This
# mruby says "undefined method" whenever a method_missing passes a call on.
# (The repeat is probed when Ruflet loads; this mruby raises "private method
# called" before any method_missing runs, so it repeats nothing.)
repeats_miss = readers.const_defined?(:REPEATS_MISS) ? readers::REPEATS_MISS : :not_defined
assert_equal(RUBY_ENGINE != "mruby", repeats_miss, "repeated-miss probe")
class ReaderProtectedHolder
  def guarded
    :guarded
  end
  protected :guarded
end
earlier_misses = [
  ["no earlier miss", lambda { nil }],
  ["a rescued bare word", lambda { begin; some_bare_word_that_is_missing; rescue NameError; end }],
  ["a rescued private call", lambda { begin; Object.new.puts("x"); rescue NoMethodError; end }],
  ["a rescued protected call", lambda { begin; ReaderProtectedHolder.new.guarded; rescue NoMethodError; end }],
  ["a bare local_auth", lambda { local_auth }]
]
def reader_error(receiver)
  yield
  [:no_error]
rescue NoMethodError => e
  result = [e.message.split(" ").first(2).join(" "), e.name, e.args]
  result << e.receiver.equal?(receiver) if e.respond_to?(:receiver)
  result << e.private_call? if e.respond_to?(:private_call?)
  result
rescue NameError => e
  [:escaped_rescue_nomethoderror, e.class]
end
def raised_by_main(kind, name)
  RUBY_ENGINE == "mruby" ? ["undefined method", name, []] : [kind, name, [], true, false]
end
earlier_misses.each do |label, miss|
  miss.call
  assert_equal(raised_by_main("undefined method", :selected_index), reader_error(tabs) { tabs.selected_index },
               "after #{label}, a name method_missing passes on raises what it raised without the reader")
end
Object.class_eval do
  def selected_index
    :top_level_helper
  end
  private :selected_index
end
earlier_misses.each do |label, miss|
  miss.call
  assert_equal(raised_by_main("private method", :selected_index), reader_error(tabs) { tabs.selected_index },
               "after #{label}, with a private Object#selected_index too")
end
Object.send(:remove_method, :selected_index)
Ruflet::Control.class_eval do
  def selected_index
    :protected_control_method
  end
  protected :selected_index
end
earlier_misses.each do |label, miss|
  miss.call
  assert_equal(raised_by_main("protected method", :selected_index), reader_error(tabs) { tabs.selected_index },
               "after #{label}, with a protected Ruflet::Control#selected_index too")
end
Ruflet::Control.send(:remove_method, :selected_index)

Ruflet::Control.send(:remove_method, :method_missing)
assert_equal(false, toggle.value, "the reader answers again once method_missing is gone")

# CRuby warns that redefining Object#method_missing may loop; this one does not.
verbose = $VERBOSE
$VERBOSE = nil
Object.class_eval do
  def method_missing(name, *args, **options, &block)
    name == :value ? :global_method_missing : super
  end
end
$VERBOSE = verbose
assert_equal(:global_method_missing, toggle.value, "an Object#method_missing the app adds still answers")
Object.send(:remove_method, :method_missing)
assert_equal(false, toggle.value, "the reader answers again once Object#method_missing is gone")

module Kernel
  alias_method :ruflet_method_missing_for_test, :method_missing
  def method_missing(name, *args, **props, &block)
    name == :value ? :wrapped : ruflet_method_missing_for_test(name, *args, **props, &block)
  end
  private :method_missing
end
assert_equal(:wrapped, toggle.value, "an app wrapping Ruflet's Kernel#method_missing still answers")
module Kernel
  alias_method :method_missing, :ruflet_method_missing_for_test
  private :method_missing
  remove_method :ruflet_method_missing_for_test
end
assert_equal(false, toggle.value, "the reader answers again once Ruflet's method_missing is back")

# A method_missing after Ruflet's own Kernel#method_missing in the lookup: in a
# module the app includes into Kernel, or on BasicObject in place of Ruby's
# own. Ruflet's Kernel#method_missing, and the SharedControlForwarders one
# after it, pass a plain call on with super, so CRuby's `toggle.value` reached
# it without the reader, and it still does. (This mruby stopped a call with a
# receiver at Ruflet's private Kernel#method_missing and raised "private method
# 'value' called"; the reader now reaches the app's there too.) With an
# argument the call reaches Ruflet's Kernel#method_missing, as without the
# reader: on CRuby that builds a generic control for a Ruflet object, and the
# VM passes the call on. The modules stay included, empty, for the rest of the
# file.
module LaterKernelMethodMissing
  def method_missing(name, *args, **options, &block)
    name == :value ? [:kernel_module, args, options] : super
  end
end
Kernel.send(:include, LaterKernelMethodMissing)
after_kernel_names = Object.ancestors
assert(after_kernel_names.index(Kernel) < after_kernel_names.index(LaterKernelMethodMissing) &&
         after_kernel_names.index(LaterKernelMethodMissing) < after_kernel_names.index(Ruflet::UI::SharedControlForwarders),
       "a module included into Kernel after Ruflet loads comes between Kernel and SharedControlForwarders")
assert_equal([:kernel_module, [], {}], toggle.value, "a method_missing in a module included into Kernel answers")
with_argument = begin
  toggle.value(1)
rescue ArgumentError => e
  e
end
if RUBY_ENGINE == "mruby"
  assert_equal([:kernel_module, [1], {}], with_argument, "the VM's Kernel#method_missing passes an argument on to it")
else
  generic = with_argument.is_a?(Ruflet::Control) ? [with_argument.type, with_argument.props["value"]] : with_argument
  assert_equal(["value", 1], generic, "CRuby's Kernel#method_missing builds a generic control for a call with an argument")
end
assert_raises(NoMethodError, "a name that method_missing does not answer still raises") { tabs.selected_index }
earlier_misses.each do |label, miss|
  miss.call
  assert_equal(raised_by_main("undefined method", :selected_index), reader_error(tabs) { tabs.selected_index },
               "after #{label}, a name the module's method_missing passes on raises what it raised without the reader")
end
LaterKernelMethodMissing.send(:remove_method, :method_missing)
assert_equal(false, toggle.value, "the reader answers again once that method_missing is gone")
# Included into Kernel before Ruflet loads, such a module comes after
# SharedControlForwarders instead. The VM always loads Ruflet first, so this
# puts one in that place by including it into SharedControlForwarders.
module EarlierKernelMethodMissing
  def method_missing(name, *args, **options, &block)
    name == :value ? [:earlier_kernel_module, args, options] : super
  end
end
Ruflet::UI::SharedControlForwarders.send(:include, EarlierKernelMethodMissing)
after_kernel_names = Object.ancestors
assert(after_kernel_names.index(Ruflet::UI::SharedControlForwarders) < after_kernel_names.index(EarlierKernelMethodMissing) &&
         after_kernel_names.index(EarlierKernelMethodMissing) < after_kernel_names.index(BasicObject),
       "that module comes between SharedControlForwarders and BasicObject")
assert_equal([:earlier_kernel_module, [], {}], toggle.value, "a method_missing after SharedControlForwarders answers")
assert_raises(NoMethodError, "a name that one does not answer still raises") { tabs.selected_index }
EarlierKernelMethodMissing.send(:remove_method, :method_missing)
assert_equal(false, toggle.value, "the reader answers again once that one is gone")
# Ruby's own BasicObject#method_missing raises and calls nothing after it, so a
# module included into BasicObject was never reached, and does not count.
module UnreachedMethodMissing
  def method_missing(name, *args, **options, &block)
    name == :value ? :never_reached : super
  end
end
BasicObject.send(:include, UnreachedMethodMissing)
assert_equal(false, toggle.value, "a method_missing after Ruby's own does not count")
UnreachedMethodMissing.send(:remove_method, :method_missing)
class BasicObject
  alias_method :ruby_method_missing_for_test, :method_missing
  private :ruby_method_missing_for_test
  def method_missing(name, *args, **options, &block)
    return ruby_method_missing_for_test(name, *args, **options, &block) unless name == :value

    [:basic_object, args, options]
  end
end
assert_equal([:basic_object, [], {}], toggle.value, "a BasicObject#method_missing the app puts in place of Ruby's answers")
assert_raises(NoMethodError, "a name it does not answer still raises") { tabs.selected_index }
class BasicObject
  alias_method :method_missing, :ruby_method_missing_for_test
  private :method_missing
  remove_method :ruby_method_missing_for_test
end
assert_equal(false, toggle.value, "the reader answers again once Ruby's own BasicObject#method_missing is back")
# An app wrapper around Ruflet's SharedControlForwarders#method_missing is the
# app's too: a plain call reached it through Ruflet's Kernel#method_missing.
module Ruflet::UI::SharedControlForwarders
  alias_method :ruflet_method_missing_for_test, :method_missing
  def method_missing(name, *args, **options, &block)
    name == :value ? [:forwarders, args, options] : ruflet_method_missing_for_test(name, *args, **options, &block)
  end
end
assert_equal([:forwarders, [], {}], toggle.value, "an app wrapper around SharedControlForwarders#method_missing answers")
assert_raises(NoMethodError, "a name the wrapper does not answer still raises") { tabs.selected_index }
module Ruflet::UI::SharedControlForwarders
  alias_method :method_missing, :ruflet_method_missing_for_test
  remove_method :ruflet_method_missing_for_test
end
assert_equal(false, toggle.value, "the reader answers again once Ruflet's SharedControlForwarders#method_missing is back")
# A module prepended to Kernel (a require hook, say) comes before Kernel in
# Kernel's own ancestors; with no method_missing of its own it changes nothing.
# It stays prepended for the rest of the file.
module PrependedKernelHelpers
  def prepended_helper
    :helper
  end
end
Kernel.send(:prepend, PrependedKernelHelpers)
assert_equal([1, false], [Kernel.ancestors.index(Kernel), toggle.value],
             "a module prepended to Kernel without a method_missing changes nothing")

class AnsweringSwitch < Ruflet::UI::Controls::RufletComponents::SwitchControl
  def method_missing(name, *args, **options, &block)
    name == :value ? [:subclass, props["value"]] : super
  end
end
class PlainSwitch < Ruflet::UI::Controls::RufletComponents::SwitchControl
end
assert_equal([:subclass, true], AnsweringSwitch.new(value: true).value, "a subclass method_missing still answers")
assert_equal(true, PlainSwitch.new(value: true).value, "a plain subclass gets the reader")

single = Ruflet.switch(label: "Single", value: false)
def single.method_missing(name, *args, **options, &block)
  name == :value ? :object_method_missing : super
end
assert_equal(:object_method_missing, single.value, "an object's own method_missing still answers")
extended = Ruflet.switch(label: "Extended", value: false)
extended.extend(Module.new do
  def method_missing(name, *args, **options, &block)
    name == :value ? :extended_method_missing : super
  end
end)
assert_equal(:extended_method_missing, extended.value, "a method_missing from extend still answers")
assert_equal(false, toggle.value, "other controls still get the reader")

Object.class_eval do
  def value
    :object
  end
end
assert_equal(:object, toggle.value, "a public Object#value still answers")
Object.send(:remove_method, :value)
Kernel.class_eval do
  def value
    :kernel
  end
end
assert_equal(:kernel, toggle.value, "a public Kernel#value still answers")
Kernel.send(:remove_method, :value)
Object.class_eval do
  def value
    :top_level_helper
  end
  private :value
end
assert_equal(:top_level_helper, toggle.instance_eval { value }, "a private Object helper still answers a call without a receiver")
assert_equal(:top_level_helper, toggle.value, "a private Object helper answers control.value")
Object.send(:remove_method, :value)
assert_equal(false, toggle.value, "the reader answers again once the helper is gone")

tabs.define_singleton_method(:selected_index) { :object }
assert_equal(:object, tabs.selected_index, "singleton method")

# Modules cannot be taken out again, so these come last.
later_tabs = Ruflet.tabs(selected_index: 1, length: 2, content: Ruflet.text("x"))
Ruflet::Control.send(:include, Module.new { def selected_index; :included; end })
assert_equal(:included, later_tabs.selected_index, "module included into Ruflet::Control")
Ruflet::Control.send(:prepend, Module.new { def selected_index; :prepended; end })
assert_equal(:prepended, later_tabs.selected_index, "module prepended to Ruflet::Control")
Ruflet::UI::Controls::RufletComponents::TabsControl.send(:include, Module.new { def selected_index; "from module"; end })
assert_equal("from module", later_tabs.selected_index, "module included into the table class")

# -- An extension helper named like a reader ----------------------------------
# register_control gives an extension registered after Ruflet loads a private
# Kernel DSL helper. Ruflet's own helper is not an app method: a plain read
# returns the state and builds nothing; calls with arguments or a block still
# reach the helper. Last, because the helper cannot be taken out again.
class ExpandedTestControl < Ruflet::Control
  def initialize(**props)
    super(type: "expanded", **props)
  end
end
registered = begin
  Ruflet::Extensions.register_control(:expanded, control_class: ExpandedTestControl)
  true
rescue TypeError
  # This mruby rejects the String helper name register_control passes to
  # Kernel.send(:private, ...), on main too: a separate, earlier bug.
  false
end
assert(registered || RUBY_ENGINE == "mruby", "register_control works on CRuby")
if registered
  tile = Ruflet.expansion_tile(title: Ruflet.text("More"), expanded: true)
  pending_roots = Ruflet::DSL._pending_app.instance_variable_get(:@roots).length
  assert_equal(true, tile.expanded, "tile.expanded reads the state, not the extension helper")
  assert_equal(pending_roots, Ruflet::DSL._pending_app.instance_variable_get(:@roots).length,
               "tile.expanded builds no control")
  built = tile.instance_eval { expanded(content: Ruflet.text("body")) }
  assert_equal("expanded", built.type, "the helper with arguments still builds the control")
  built = tile.instance_eval { expanded { nil } }
  assert_equal("expanded", built.type, "the helper with a block still builds the control")
  other_tile = Ruflet.expansion_tile(title: Ruflet.text("Other"), expanded: true)
  def other_tile.method_missing(name, *args, **options, &block)
    name == :expanded ? :object_method_missing : super
  end
  assert_equal(:object_method_missing, other_tile.expanded, "an app method_missing still answers")
  # With an app method_missing on Ruflet::Control, calls from inside the tile
  # go to it too (the "Not covered" case), with or without arguments.
  Ruflet::Control.class_eval do
    def method_missing(name, *args, **options, &block)
      name == :expanded ? :control_method_missing : super
    end
  end
  assert_equal(:control_method_missing, tile.expanded, "an app Ruflet::Control#method_missing answers tile.expanded")
  assert_equal(:control_method_missing, tile.instance_eval { expanded },
               "an app method_missing gets a bare expanded from inside the tile")
  assert_equal(:control_method_missing, tile.instance_eval { expanded(content: Ruflet.text("body")) },
               "an app method_missing gets expanded(...) from inside the tile")
  Ruflet::Control.send(:remove_method, :method_missing)
  assert_equal(true, tile.expanded, "tile.expanded reads the state again once method_missing is gone")

  # App methods of that name still answer: a private Object method (a
  # top-level helper), then the app's own Kernel#expanded.
  Object.class_eval do
    def expanded(**options)
      :top_level_helper
    end
    private :expanded
  end
  assert_equal(:top_level_helper, tile.instance_eval { expanded }, "a private Object#expanded still answers")
  Object.send(:remove_method, :expanded)
  module Kernel
    def expanded(**options)
      :app_kernel_method
    end
    private :expanded
  end
  assert_equal(:app_kernel_method, tile.instance_eval { expanded }, "an app Kernel#expanded still answers")

  # A module the table class includes comes before Kernel too.
  class SelectionTestControl < Ruflet::Control
    def initialize(**props)
      super(type: "selection", **props)
    end
  end
  Ruflet::Extensions.register_control(:selection, control_class: SelectionTestControl)
  text_input = Ruflet.text_field(label: "Name", value: "Ada")
  assert_equal(nil, text_input.selection, "text_field.selection reads the state, not the extension helper")
  Ruflet::UI::Controls::TextInputMethods.class_eval do
    def selection
      :text_input_method
    end
  end
  assert_equal(:text_input_method, text_input.selection, "a TextInputMethods#selection the app adds still answers")
end

if $failures.empty?
  puts "client_state_readers_test (#{RUBY_ENGINE}): #{$tests} assertions passed"
else
  puts "client_state_readers_test (#{RUBY_ENGINE}): #{$failures.length} of #{$tests} failed"
  $failures.each { |failure| puts "  #{failure}" }
  raise "client state reader failures"
end
