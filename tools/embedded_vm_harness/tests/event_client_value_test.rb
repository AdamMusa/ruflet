# frozen_string_literal: true
#
# A control's value reaches its handler as the String the client sent, also
# when it looks like JSON. packages/ruflet_core/test/event_client_value_test.rb
# guards this on CRuby. This is the same contract on the embedded VM, whose
# JSON (ruby_runtime/vm/stdlib/json.rb) decodes even "007" as 7.
#
# The compiled framework does not load JSON by itself: Ruflet::Event decodes
# String payloads only once something has required "json" (an app or a gem
# usually has), so this file requires it to exercise that path.
#
# Valid mruby and CRuby (no Regexp, no defined?, no string eval).
#
# Run: embedded_mruby --preload tools/embedded_vm_harness/tests/event_client_value_test.rb
#  or: ruby -Ipackages/ruflet_core/lib tools/embedded_vm_harness/tests/event_client_value_test.rb
require "ruflet_core"
require "json"

failures = 0

check = lambda do |label, actual, expected|
  if actual == expected && actual.class == expected.class
    print "."
  else
    failures += 1
    puts "\nFAIL #{label}: expected #{expected.inspect}, got #{actual.inspect}"
  end
end

page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})

# What the client sends when the user types or picks +value+: update_control,
# then the event with the same String as data.
client_sends = lambda do |control, name, value|
  page.apply_client_update(control.wire_id, { "value" => value })
  page.dispatch_event(target: control.wire_id, name: name, data: value)
end

seen = []
field = Ruflet.text_field(on_change: ->(e) { seen << [e.data, e.control.props["value"]] })
strings = Ruflet.dropdown(
  value: "1",
  options: [Ruflet.dropdown_option(key: "1", text: "One"), Ruflet.dropdown_option(key: "2", text: "Two")],
  on_select: ->(e) { seen << e.data }
)
ints = Ruflet.dropdown(
  value: 1,
  options: [Ruflet.dropdown_option(key: 1, text: "One"), Ruflet.dropdown_option(key: 2, text: "Two")],
  on_select: ->(e) { seen << e.data }
)
group = Ruflet.radio_group(
  value: "10",
  content: Ruflet.column(controls: [Ruflet.radio(value: "10"), Ruflet.radio(value: "20")]),
  on_change: ->(e) { seen << [e.data, e.control.props["value"]] }
)
int_group = Ruflet.radio_group(
  value: 10,
  content: Ruflet.column(controls: [Ruflet.radio(value: 10), Ruflet.radio(value: 20)]),
  on_change: ->(e) { seen << [e.data, e.control.props["value"]] }
)
m2_ints = Ruflet.dropdown_m2(
  options: [Ruflet.option(key: 1), Ruflet.option(text: 2)],
  on_change: ->(e) { seen << e.data }
)
mixed = Ruflet.dropdown(
  options: [Ruflet.dropdown_option(key: 2, text: "Two"), Ruflet.dropdown_option(key: "2", text: "String two")],
  on_select: ->(e) { seen << e.data }
)
form_group = Ruflet.radio_group(
  content: Ruflet.form(controls: [Ruflet.radio(value: 1), Ruflet.radio(value: 2)]),
  on_change: ->(e) { seen << e.data }
)
suffix_field = Ruflet.text_field(suffix: Ruflet.radio(value: 5), on_change: ->(e) { seen << e.data })
search = Ruflet.search_bar(capitalization: "characters", on_change: ->(e) { seen << e.data })
menu = Ruflet.popup_menu_button([Ruflet.popup_menu_item("Edit")], on_select: ->(e) { seen << e.data })
page.add(Ruflet.column(controls: [field, strings, ints, group, int_group, m2_ints, mixed, form_group, suffix_field, search, menu]))

["123", "007", "2.50", "null", "true", "[1]", "{\"a\":1}"].each do |typed|
  seen.clear
  client_sends.call(field, "change", typed)
  check.call("text field #{typed.inspect}", seen.first, [typed, typed])
end

seen.clear
client_sends.call(strings, "select", "2")
check.call("string option key", seen.first, "2")

seen.clear
client_sends.call(ints, "select", "2")
check.call("Integer option key", seen.first, 2)

seen.clear
client_sends.call(group, "change", "20")
check.call("string radio value", seen.first, %w[20 20])

seen.clear
client_sends.call(int_group, "change", "20")
check.call("Integer radio value", seen.first, [20, 20])

seen.clear
client_sends.call(m2_ints, "select", "2")
check.call("Integer text-only option", seen.first, 2)

seen.clear
client_sends.call(mixed, "select", "2")
check.call("options declaring 2 and \"2\"", seen.first, 2)

seen.clear
client_sends.call(form_group, "change", "2")
check.call("Integer radio inside a form", seen.first, 2)

seen.clear
client_sends.call(suffix_field, "change", "5")
check.call("text field holding a radio", seen.first, "5")

# The search bar syncs the capitalized text and sends it as typed.
seen.clear
page.apply_client_update(search.wire_id, { "value" => "TRUE" })
page.dispatch_event(target: search.wire_id, name: "change", data: "true")
check.call("capitalized search bar", seen.first, "true")

# Not a control's own value: decoded as before.
seen.clear
page.dispatch_event(target: menu.wire_id, name: "select", data: "42")
check.call("popup menu item id", seen.first, 42)

seen.clear
page.dispatch_event(target: field.wire_id, name: "change", data: "{\"value\":\"x\"}")
check.call("JSON object payload", seen.first, [{ "value" => "x" }, "x"])

puts
if failures.zero?
  puts "event client values: all checks passed"
else
  puts "event client values: #{failures} failure(s)"
  raise "event client value test failed"
end
