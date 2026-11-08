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

# -- Every reader in the table is defined, publicly, on its class ------------
assert_equal([], readers.install!, "install! skipped no reader")
count = 0
readers.table.each do |klass, names|
  names.each do |name|
    count += 1
    assert(klass.public_method_defined?(name.to_sym), "#{klass}##{name} is public")
    assert(klass.instance_methods(false).include?(name.to_sym), "#{klass}##{name} is defined on the class itself")
  end
end
assert_equal(51, count, "reader count")

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

stepper = Ruflet.stepper(steps: [])
assert_equal("stepper", stepper.type, "Control#type is not shadowed")
assert_equal([toggle], [[toggle]].flatten, "flatten")

generic = Ruflet::Control.new(type: "my_extension_widget", value: 3)
assert_raises(NoMethodError, "schema-less control has no reader") { generic.value }

if $failures.empty?
  puts "client_state_readers_test (#{RUBY_ENGINE}): #{$tests} assertions passed"
else
  puts "client_state_readers_test (#{RUBY_ENGINE}): #{$failures.length} of #{$tests} failed"
  $failures.each { |failure| puts "  #{failure}" }
  raise "client state reader failures"
end
