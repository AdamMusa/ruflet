# frozen_string_literal: true

require_relative "test_helper"

# Ruflet::Extensions.register_control makes a helper available in the bare
# DSL, Ruflet, Ruflet::UI, Ruflet::DSL and widget builders (see
# docs/extension_authoring.md). Before Stepper, Table, CarouselView and the
# other controls added after v0.0.23 were built in, an app or extension gem
# registering one of them under its own name got that helper everywhere.
# Being built in now must not take any of those entry points away from it.
class ExtensionHelperCollisionTest < Minitest::Test
  NAMES = %i[
    about_dialog aboutdialog carousel_view carouselview custom_scroll_view customscrollview
    draggable_scrollable_sheet draggablescrollablesheet fitted_box fittedbox form_row formrow
    indexed_stack indexedstack list_section listsection sliver_app_bar sliverappbar
    sliver_fill_remaining sliverfillremaining sliver_grid slivergrid sliver_list sliverlist
    sliver_to_box_adapter slivertoboxadapter stepper stepper_step stepperstep table table_row tablerow
  ].freeze

  ENTRY_POINTS = [
    "Ruflet.<name>", "Ruflet::UI.<name>", "Ruflet::DSL.<name>", "WidgetBuilder#<name>",
    "Ruflet.column { <name> }", "DSL.app { <name> }", "top level <name>(...)", "top level <name>",
    "App#view <name>(...)", "component <name>(...)", "Object.new.<name>(...)"
  ].freeze

  # Registering is process-wide and permanent, so it runs in a child process
  # and the rest of the suite keeps the built-in helpers.
  def test_an_extension_registered_under_a_built_in_name_wins_at_every_entry_point
    results = run_child(<<~RUBY)
      NAMES = #{NAMES.inspect}
      module CollisionExtension; end
      NAMES.each do |name|
        type = "collision_\#{name}"
        klass = Class.new(Ruflet::Control) do
          const_set(:TYPE, type)
          const_set(:KEYWORDS, %i[items].freeze)
          define_method(:initialize) { |id: nil, **props| super(type: type, id: id, **props) }
        end
        CollisionExtension.const_set("Control_\#{name}", klass)
        Ruflet::Extensions.register_control(name, control_class: klass)
      end

      app_class = Class.new(Ruflet::App)
      component_class = Class.new
      NAMES.each do |name|
        app_class.class_eval("def via_\#{name} = \#{name}(items: 1)")
        component_class.class_eval("def via_\#{name} = \#{name}(items: 1)")
      end

      calls = {
        "Ruflet.<name>" => ->(n) { Ruflet.public_send(n, items: 1) },
        "Ruflet::UI.<name>" => ->(n) { Ruflet::UI.public_send(n, items: 1) },
        "Ruflet::DSL.<name>" => ->(n) { Ruflet::DSL.public_send(n, items: 1) },
        "WidgetBuilder#<name>" => ->(n) { Ruflet::WidgetBuilder.new.public_send(n, items: 1) },
        "Ruflet.column { <name> }" => ->(n) { TOPLEVEL_BINDING.eval("Ruflet.column { \#{n}(items: 1) }").children.first },
        "DSL.app { <name> }" => lambda do |n|
          Ruflet::DSL._reset_pending_app!
          TOPLEVEL_BINDING.eval("Ruflet::DSL.app { \#{n}(items: 1) }").instance_variable_get(:@roots).last
        end,
        "top level <name>(...)" => ->(n) { TOPLEVEL_BINDING.eval("\#{n}(items: 1)") },
        "top level <name>" => ->(n) { TOPLEVEL_BINDING.eval(n.to_s) },
        "App#view <name>(...)" => ->(n) { app_class.new.public_send("via_\#{n}") },
        "component <name>(...)" => ->(n) { component_class.new.public_send("via_\#{n}") },
        "Object.new.<name>(...)" => ->(n) { TOPLEVEL_BINDING.eval("Object.new.\#{n}(items: 1)") }
      }

      calls.each do |label, call|
        NAMES.each do |name|
          result =
            begin
              control = call.call(name)
              control.is_a?(CollisionExtension.const_get("Control_\#{name}")) ? "extension" : control.class.to_s
            rescue StandardError => e
              "\#{e.class}: \#{e.message}"
            end
          puts [label, name, result].join("\\t")
        end
      end
    RUBY

    assert_equal ENTRY_POINTS.product(NAMES.map(&:to_s)).size, results.size

    wrong = results.reject { |_label, _name, result| result == "extension" }
    assert_empty wrong.map { |row| row.join(" ") }, "these calls did not reach the registered extension"
    assert_equal ENTRY_POINTS, results.map(&:first).uniq
  end

  private

  def run_child(body)
    core_lib = File.expand_path("../lib", __dir__)
    script = "$LOAD_PATH.unshift #{core_lib.inspect}\nrequire \"ruflet_core\"\n#{body}"
    output = IO.popen([RbConfig.ruby, "-e", script], err: %i[child out], &:read)

    assert $?.success?, output
    output.lines(chomp: true).map { |line| line.split("\t", 3) }
  end
end
