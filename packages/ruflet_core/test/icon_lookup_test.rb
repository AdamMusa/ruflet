# frozen_string_literal: true

require_relative "test_helper"

class RufletIconLookupTest < Minitest::Test
  # The icon modules are large and unused by the common icon("name") path, so
  # they are autoloaded (deferred) rather than required at boot. This test is a
  # marker for that contract — if it regresses to eager loading, boot slows.
  def test_icon_modules_are_deferred_until_referenced
    skip "mruby concatenates the framework and does not autoload" if RUBY_ENGINE == "mruby"

    # A subprocess so prior tests referencing icons do not mask the deferral.
    core_lib = File.expand_path("../lib", __dir__)
    protocol_lib = core_lib # ruflet_protocol ships in the same gem lib
    script = <<~RUBY
      $LOAD_PATH.unshift #{core_lib.inspect}, #{protocol_lib.inspect}
      require "ruflet_core"
      pending = Ruflet.autoload?(:MaterialIcons) ? "deferred" : "eager"
      resolved = (Ruflet::Icons::HOME rescue "ERR")
      print [pending, resolved].join(",")
    RUBY
    out = IO.popen([RbConfig.ruby, "-e", script], &:read)
    pending, resolved = out.split(",")
    assert_equal "deferred", pending, "icon modules must be autoloaded, not required at boot"
    assert_equal "home", resolved, "referencing an icon constant must still resolve after autoload"
  end

  def test_material_icon_lookup_uses_local_json
    assert_equal 65604, Ruflet::MaterialIconLookup.codepoint_for("add")
    assert_equal 65604, Ruflet::MaterialIconLookup.codepoint_for(:add)
    assert_equal "add", Ruflet::MaterialIconLookup.canonical_name_for(:add)
  end

  def test_cupertino_icon_lookup_uses_local_json
    refute_nil Ruflet::CupertinoIconLookup.codepoint_for("add")
    refute_nil Ruflet::CupertinoIconLookup.codepoint_for(:search)
    assert_equal "add", Ruflet::CupertinoIconLookup.canonical_name_for(:add)
  end

  def test_icons_groups_expose_material_and_cupertino
    assert_equal Ruflet::MaterialIcons::ADD, Ruflet::Icons.material[:add]
    assert_equal Ruflet::CupertinoIcons::ADD, Ruflet::Icons.cupertino[:add]
  end
end
