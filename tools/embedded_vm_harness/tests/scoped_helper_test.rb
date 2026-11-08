# frozen_string_literal: true
#
# The helpers added after v0.0.23 (Ruflet::UI::ScopedControlForwarders:
# `stepper`, `table`, `form`, ...) are not Kernel methods. A bare call reaches
# them through Kernel#method_missing, and an object with a method_missing of
# its own keeps the name.
#
# packages/ruflet_core/test/kernel_helper_shadowing_test.rb guards this on
# CRuby. This is the same contract on the embedded VM, where method_missing is
# reached differently: send passes keywords as a trailing Hash, there is no
# NoMethodError#private_call?, and mruby 449627d drops the keywords of a call
# that also splats positional arguments (see the last section).
#
# Valid mruby and CRuby (no Regexp, no defined?, no string eval).
#
# Run: embedded_mruby --preload tools/embedded_vm_harness/tests/scoped_helper_test.rb
#  or: ruby -Ipackages/ruflet_core/lib tools/embedded_vm_harness/tests/scoped_helper_test.rb
require "ruflet_core"

failures = 0
skipped = 0

check = lambda do |label, actual, expected|
  if actual == expected
    print "."
  else
    failures += 1
    puts "\nFAIL #{label}: expected #{expected.inspect}, got #{actual.inspect}"
  end
end

without_ids = lambda do |value|
  if value.is_a?(Hash)
    result = {}
    value.each { |key, item| result[key] = without_ids.call(item) unless key == "_i" || key == "id" }
    result
  elsif value.is_a?(Array)
    value.map { |item| without_ids.call(item) }
  else
    value
  end
end

# A call's patch without ids, or the class of the error it raises.
outcome = lambda do |&call|
  begin
    without_ids.call(call.call.to_patch)
  rescue StandardError => e
    e.class
  end
end

# Every bare helper added since v0.0.23.
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

# -- Not Kernel methods ---------------------------------------------------------
NEW_HELPERS.each do |name|
  check.call("Kernel##{name} is not defined", Kernel.private_method_defined?(name) || Kernel.method_defined?(name), false)
end

# -- Bare calls build what Ruflet::DSL builds -------------------------------------
plain = Object.new
check.call("bare stepper(current_step: 1)",
           outcome.call { plain.instance_eval { stepper(current_step: 1) } },
           outcome.call { Ruflet::DSL.stepper(current_step: 1) })
check.call("bare table(rows: [])",
           outcome.call { plain.instance_eval { table(rows: []) } },
           outcome.call { Ruflet::DSL.table(rows: []) })
check.call("bare about_dialog", outcome.call { plain.instance_eval { about_dialog } }, outcome.call { Ruflet::DSL.about_dialog })
check.call("bare form { }",
           outcome.call { plain.instance_eval { form { text_field(label: "N") } } },
           outcome.call { Ruflet::DSL.form { text_field(label: "N") } })

# -- send passes its keywords to method_missing as a trailing Hash ------------------
check.call("send(:stepper, current_step: 1)",
           outcome.call { Object.new.send(:stepper, current_step: 1) },
           outcome.call { Ruflet::DSL.stepper(current_step: 1) })
check.call("__send__(:table, rows: [])",
           outcome.call { Object.new.__send__(:table, rows: []) },
           outcome.call { Ruflet::DSL.table(rows: []) })
check.call("send(:about_dialog, application_name: \"A\")",
           outcome.call { Object.new.send(:about_dialog, application_name: "A") },
           outcome.call { Ruflet::DSL.about_dialog(application_name: "A") })

# -- Explicit receivers raise, as when the names did not exist ----------------------
check.call("Object.new.table(rows: [])", outcome.call { Object.new.table(rows: []) }, NoMethodError)
check.call("Object.new.stepper", outcome.call { Object.new.stepper }, NoMethodError)

# -- Another library's method_missing builder keeps the names -----------------------
class ScopedHelperTagBuilder
  attr_reader :tags

  def initialize
    @tags = []
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
tags =
  begin
    ScopedHelperTagBuilder.new.instance_eval { table { form(action: "/x") { stepper } } }.tags
  rescue StandardError => e
    e.class
  end
check.call("tag builder gets table, form, stepper", tags, %i[table form stepper])

# -- Forwarding a helper from a wrapper ----------------------------------------------
class ScopedHelperWrapper
  def named_stepper(steps = nil, **props, &block) = stepper(steps, **props, &block)
  def named_list_section(children = nil, **props, &block) = list_section(children, **props, &block)
  def keywords_about_dialog(**props) = about_dialog(**props)
  def splat_stepper(*args, **props, &block) = stepper(*args, **props, &block)
  def splat_list_section(*args, **props, &block) = list_section(*args, **props, &block)
  def splat_fade_transition(*args, **props, &block) = fade_transition(*args, **props, &block)
  def splat_about_dialog(*args, **props, &block) = about_dialog(*args, **props, &block)
  def splat_form(*args, **props, &block) = form(*args, **props, &block)
  def literal_table(*args) = table(*args, border_width: 1)
  def dots_table(...) = table(...)
end
wrapper = ScopedHelperWrapper.new
step = Ruflet::DSL.stepper_step(title: "A")

# Named positional parameters forward their keywords on every runtime.
check.call("named stepper(steps, current_step: 1)",
           outcome.call { wrapper.named_stepper([step], current_step: 1) },
           outcome.call { Ruflet::DSL.stepper([step], current_step: 1) })
check.call("named list_section(children, header:)",
           outcome.call { wrapper.named_list_section([Ruflet::DSL.text("i")], header: Ruflet::DSL.text("H")) },
           outcome.call { Ruflet::DSL.list_section([Ruflet::DSL.text("i")], header: Ruflet::DSL.text("H")) })
check.call("keywords about_dialog(application_name:)",
           outcome.call { wrapper.keywords_about_dialog(application_name: "A") },
           outcome.call { Ruflet::DSL.about_dialog(application_name: "A") })

# mruby 449627d loses the keywords of any call that both splats positional
# arguments and passes keywords (`name(*args, **opts)`, `name(*args, k: 1)`,
# `name(...)`) to a method that is not defined: prepare_missing() in
# src/vm.c reads them from argv[ci->n], past the frame, where a splat call
# holds them in argv[1]. Every such call to one of these helpers goes there,
# as one to a v0.0.23 control without a forwarder (`elevatedbutton`) already
# did. A pure-Ruby probe tells whether this VM has that bug; the checks below
# run where it does not (CRuby, or a VM built with the fix), so they pin the
# behaviour the fix must give.
class ScopedHelperKeywordProbe
  def method_missing(_name, *_args, **props) = props
  def respond_to_missing?(_name, _include_private = false) = true
  def forward(*args, **props) = probe_missing_name(*args, **props)
end
splat_keywords_arrive =
  begin
    ScopedHelperKeywordProbe.new.forward(1, probe: "scoped-helper") == { probe: "scoped-helper" }
  rescue StandardError
    false
  end

if splat_keywords_arrive
  check.call("splat stepper(steps, current_step: 1)",
             outcome.call { wrapper.splat_stepper([step], current_step: 1) },
             outcome.call { Ruflet::DSL.stepper([step], current_step: 1) })
  check.call("splat stepper(current_step: 1)",
             outcome.call { wrapper.splat_stepper(current_step: 1) },
             outcome.call { Ruflet::DSL.stepper(current_step: 1) })
  check.call("splat list_section(children, header:)",
             outcome.call { wrapper.splat_list_section([Ruflet::DSL.text("i")], header: Ruflet::DSL.text("H")) },
             outcome.call { Ruflet::DSL.list_section([Ruflet::DSL.text("i")], header: Ruflet::DSL.text("H")) })
  check.call("splat fade_transition(content, repeat: true)",
             outcome.call { wrapper.splat_fade_transition(Ruflet::DSL.text("f"), repeat: true) },
             outcome.call { Ruflet::DSL.fade_transition(Ruflet::DSL.text("f"), repeat: true) })
  check.call("splat about_dialog(application_name:)",
             outcome.call { wrapper.splat_about_dialog(application_name: "A") },
             outcome.call { Ruflet::DSL.about_dialog(application_name: "A") })
  check.call("splat form([field], key:)",
             outcome.call { wrapper.splat_form([Ruflet::DSL.text_field(label: "N")], key: "k") },
             outcome.call { Ruflet::DSL.form([Ruflet::DSL.text_field(label: "N")], key: "k") })
  check.call("splat form { }",
             outcome.call { wrapper.splat_form { Ruflet::DSL.text_field(label: "N") } },
             outcome.call { Ruflet::DSL.form { Ruflet::DSL.text_field(label: "N") } })
  check.call("literal table(rows, border_width: 1)",
             outcome.call { wrapper.literal_table([]) },
             outcome.call { Ruflet::DSL.table([], border_width: 1) })
  check.call("dots table(rows: [])", outcome.call { wrapper.dots_table(rows: []) }, outcome.call { Ruflet::DSL.table(rows: []) })
  check.call("dots table(rows, border_width: 2)",
             outcome.call { wrapper.dots_table([], border_width: 2) },
             outcome.call { Ruflet::DSL.table([], border_width: 2) })
else
  skipped += 10
  puts "\nKNOWN LIMIT: this VM's mruby drops keywords forwarded with a positional splat to a missing " \
       "method (prepare_missing in mruby 449627d src/vm.c). Skipped 10 splat-forwarding checks; " \
       "forward through named parameters (`def s(steps = nil, **opts) = stepper(steps, **opts)`) instead."
end

puts
if failures.zero?
  puts "scoped helpers: all checks passed#{skipped.zero? ? '' : " (#{skipped} skipped)"}"
else
  puts "scoped helpers: #{failures} failure(s)"
  raise "scoped helper test failed"
end
