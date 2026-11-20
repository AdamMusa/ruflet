# frozen_string_literal: true
#
# The icon tables must not be materialized while the VM opens.
#
# packages/ruflet_core/test/icon_lookup_test.rb guards this on CRuby with
# autoload, but it skips on mruby: the mrbgem concatenates the framework into
# one blob with no filesystem require, so autoload cannot apply there. This is
# the same contract, checked where it costs the most.
#
# Materializing every icon eagerly meant interning ~10,100 symbols and defining
# ~10,100 constants inside mrb_open, which was ~300ms -- the single largest item
# in an application's cold start, paid whether or not the app used one icon.
#
# Run: embedded_mruby --preload tools/embedded_vm_harness/tests/icon_deferral_test.rb

failures = 0

check = lambda do |label, actual, expected|
  if actual == expected
    print "."
  else
    failures += 1
    puts "\nFAIL #{label}: expected #{expected.inspect}, got #{actual.inspect}"
  end
end

# Nothing has referenced an icon yet, so no icon constant should exist. If this
# fails, the tables are being built at VM open again.
check.call(
  "MaterialIcons::HOME is not defined before first reference",
  Ruflet::MaterialIcons.const_defined?(:HOME, false),
  false
)
check.call(
  "CupertinoIcons::HOME is not defined before first reference",
  Ruflet::CupertinoIcons.const_defined?(:HOME, false),
  false
)

# Referencing one resolves it, and only it.
check.call("MaterialIcons::HOME resolves", Ruflet::MaterialIcons::HOME, "home")
check.call(
  "MaterialIcons::HOME is defined after reference",
  Ruflet::MaterialIcons.const_defined?(:HOME, false),
  true
)
check.call(
  "an unreferenced icon stays undefined",
  Ruflet::MaterialIcons.const_defined?(:SETTINGS, false),
  false
)

# The rest of the icon API keeps working, materializing on demand.
check.call("MaterialIcons::SETTINGS", Ruflet::MaterialIcons::SETTINGS, "settings")
check.call("MaterialIcons::ACCESS_ALARM", Ruflet::MaterialIcons::ACCESS_ALARM, "access_alarm")
check.call("MaterialIcons[:add]", Ruflet::MaterialIcons[:add], "add")
check.call("MaterialIcons['Home']", Ruflet::MaterialIcons["Home"], "home")
check.call("CupertinoIcons::HOME", Ruflet::CupertinoIcons::HOME, "home")
check.call("Icons::HOME", Ruflet::Icons::HOME, "home")
check.call("Icons.material[:add]", Ruflet::Icons.material[:add], "add")
check.call("Icons.cupertino[:add]", Ruflet::Icons.cupertino[:add], "add")

# A single name never needs the constant-name index: building it interns a
# symbol per icon, the cost this file exists to keep out of the VM.
check.call(
  "single-name lookups leave the Material constant index unbuilt",
  Ruflet::MaterialIcons.instance_variable_defined?(:@icons),
  false
)
check.call("Icons::HOUSE_FILL", Ruflet::Icons::HOUSE_FILL, "house_fill")
check.call(
  "a Cupertino-only umbrella name leaves the Material constant index unbuilt",
  Ruflet::MaterialIcons.instance_variable_defined?(:@icons),
  false
)

# ADD and HOME are in both sets with different codepoints. Main and the
# published gems (0.0.15 to 0.0.21 and 0.0.23 were checked) send Material's
# for both, whichever set the name came from, so apps show that glyph today
# and it must not change.
check.call(
  "cupertino_button(icon: CupertinoIcons::ADD) sends the published codepoint",
  Ruflet::DSL.cupertino_button("x", icon: Ruflet::CupertinoIcons::ADD).props["icon"],
  65604
)
check.call(
  "button(icon: Icons.cupertino[:add]) sends the published codepoint",
  Ruflet::DSL.button("x", icon: Ruflet::Icons.cupertino[:add]).props["icon"],
  65604
)
check.call(
  "icon(icon: CupertinoIcons::HOME) sends the published codepoint",
  Ruflet::DSL.icon(icon: Ruflet::CupertinoIcons::HOME).props["icon"],
  69217
)
check.call(
  "cupertino_button(icon: MaterialIcons::ADD) sends the published codepoint",
  Ruflet::DSL.cupertino_button("x", icon: Ruflet::MaterialIcons::ADD).props["icon"],
  65604
)
check.call(
  "a plain \"add\" still resolves Material first",
  Ruflet::DSL.cupertino_button("x", icon: "add").props["icon"],
  65604
)
check.call(
  "a Cupertino-only name sends its Cupertino codepoint",
  Ruflet::DSL.icon(icon: Ruflet::CupertinoIcons::HOUSE_FILL).props["icon"],
  131732
)

# "CLASS_" is the one icon out of 10,147 whose constant name differs from its
# map key (the trailing underscore is stripped), so Ruflet::MaterialIcons::CLASS
# is the only reference that exercises the reverse-index path rather than a
# direct hit on the compiled map.
check.call("MaterialIcons::CLASS", Ruflet::MaterialIcons::CLASS, "class_")
check.call(
  "Icons[:class] resolves once MaterialIcons::CLASS is defined",
  Ruflet::DSL.icon(icon: Ruflet::Icons[:class]).props["icon"],
  66925
)

# Whole-table accessors still see everything.
check.call("names.size", Ruflet::MaterialIcons.names.size, 8825)
check.call("ICONS.size", Ruflet::MaterialIcons::ICONS.size, 8825)
check.call("all.size", Ruflet::MaterialIcons.all.size, 8825)
check.call("constants includes HOME", Ruflet::MaterialIcons.constants.include?(:HOME), true)
check.call("codepoint_for('add')", Ruflet::MaterialIconLookup.codepoint_for("add"), 65604)
check.call("canonical_name_for(:add)", Ruflet::MaterialIconLookup.canonical_name_for(:add), "add")

puts
if failures.zero?
  puts "icon deferral: all checks passed"
else
  puts "icon deferral: #{failures} failure(s)"
  raise "icon deferral test failed"
end
