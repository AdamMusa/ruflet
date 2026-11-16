# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"

# Material and Cupertino are separate icon sets. Using one must not load the
# other (the Material table alone is a ~234KB JSON parse), and a name taken
# from one set must keep that set's codepoint on the wire: 101 names (ADD,
# HOME, ...) exist in both with different codepoints, and resolving every
# icon prop Material-first used to send Material's ADD for CupertinoIcons::ADD.
class RufletIconSetDecouplingTest < Minitest::Test
  MATERIAL_SET = 0x10000
  CUPERTINO_SET = 0x20000
  CORE_LIB = File.expand_path("../lib", __dir__)

  def test_shared_names_keep_their_set_on_every_control_family
    shared = Ruflet::MaterialIconLookup.icon_map.keys & Ruflet::CupertinoIconLookup.icon_map.keys
    assert_operator shared.size, :>=, 100, "expected the two sets to share names"

    shared.each do |key|
      constant = key.to_sym
      cupertino = Ruflet::CupertinoIcons.resolve_constant(constant)
      material = Ruflet::MaterialIcons.resolve_constant(constant)

      [:button, :cupertino_button].each do |family|
        assert_equal Ruflet::CupertinoIconLookup.icon_map[key],
                     Ruflet::DSL.public_send(family, "x", icon: cupertino).props["icon"],
                     "#{family}(icon: CupertinoIcons::#{key})"
        assert_equal Ruflet::MaterialIconLookup.icon_map[key],
                     Ruflet::DSL.public_send(family, "x", icon: material).props["icon"],
                     "#{family}(icon: MaterialIcons::#{key})"
      end
    end
  end

  def test_every_cupertino_entry_point_resolves_in_the_cupertino_set
    values = {
      "CupertinoIcons::ADD" => Ruflet::CupertinoIcons::ADD,
      "CupertinoIcons[:add]" => Ruflet::CupertinoIcons[:add],
      "Icons.cupertino[:add]" => Ruflet::Icons.cupertino[:add],
      "IconData.new(CupertinoIcons::ADD)" => Ruflet::IconData.new(Ruflet::CupertinoIcons::ADD)
    }

    values.each do |label, value|
      assert_equal CUPERTINO_SET, Ruflet::DSL.icon(icon: value).props["icon"], label
    end
    assert_equal CUPERTINO_SET, Ruflet::DSL.icon(icon: Ruflet::CupertinoIcons.random).props["icon"] & 0xF0000
  end

  def test_page_update_keeps_the_icon_set
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    control = Ruflet.icon(icon: "home")
    page.add(control)

    page.update(control, icon: Ruflet::CupertinoIcons::ADD)

    patch = sent.last[1]["patch"].find { |op| op[2] == "icon" }
    assert_equal CUPERTINO_SET, patch[3]
  end

  def test_plain_names_still_resolve_material_first
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("add"), Ruflet::DSL.cupertino_button("x", icon: "add").props["icon"]
    assert_equal Ruflet::CupertinoIconLookup.codepoint_for("house_fill"), Ruflet::DSL.button("x", icon: "house_fill").props["icon"]
  end

  def test_set_names_still_behave_as_plain_strings
    name = Ruflet::CupertinoIcons::ADD

    assert_kind_of String, name
    assert_equal "add", name
    assert_equal name, "add"
    assert_equal "icon:add", "icon:#{name}"
    assert_equal 1, { "add" => 1 }[name]
    assert_predicate name, :frozen?
    assert_equal Ruflet::IconData.new("add"), Ruflet::IconData.new(name)
  end

  def test_icons_lookup_does_not_depend_on_what_was_referenced_before
    assert_equal ["Ruflet::MaterialIconName", "Ruflet::MaterialIconName"], run_fresh(<<~RUBY).split(",")
      before = Ruflet::Icons[:add].class.name
      Ruflet::MaterialIcons::ADD
      print [before, Ruflet::Icons[:add].class.name].join(",")
    RUBY
  end

  def test_icons_lookup_accepts_names_that_are_not_constants
    assert_equal "arrow_back", Ruflet::Icons["arrow back"]
    assert_kind_of Ruflet::MaterialIconName, Ruflet::Icons["arrow back"]
    assert_kind_of Ruflet::CupertinoIconName, Ruflet::Icons["house_fill"]
    assert_kind_of Ruflet::IconData, Ruflet::Icons["not_an_icon_anywhere"]
  end

  def test_using_only_cupertino_icons_never_loads_material
    result = JSON.parse(run_fresh(<<~RUBY))
      wire = []
      wire << Ruflet::DSL.cupertino_button("x", icon: Ruflet::CupertinoIcons::ADD).props["icon"]
      wire << Ruflet::DSL.button("x", icon: Ruflet::CupertinoIcons::HOUSE_FILL).props["icon"]
      wire << Ruflet::DSL.icon(icon: Ruflet::Icons.cupertino[:search]).props["icon"]
      wire << Ruflet::DSL.icon(icon: Ruflet::IconData.new(Ruflet::CupertinoIcons::HOME)).props["icon"]
      print JSON.generate(
        "wire" => wire,
        "material_module_loaded" => !Ruflet.autoload?(:MaterialIcons),
        "material_table_loaded" => Ruflet::MaterialIconLookup.instance_variable_defined?(:@icon_map)
      )
    RUBY

    assert(result["wire"].all? { |codepoint| codepoint & 0xF0000 == CUPERTINO_SET }, result["wire"].inspect)
    refute result["material_module_loaded"], "Ruflet::MaterialIcons was loaded by Cupertino-only code"
    refute result["material_table_loaded"], "the Material icon table was parsed by Cupertino-only code"
  end

  def test_using_only_material_icons_never_loads_cupertino
    result = JSON.parse(run_fresh(<<~RUBY))
      wire = []
      wire << Ruflet::DSL.button("x", icon: Ruflet::MaterialIcons::ADD).props["icon"]
      wire << Ruflet::DSL.cupertino_button("x", icon: Ruflet::MaterialIcons::HOME).props["icon"]
      wire << Ruflet::DSL.icon(icon: Ruflet::Icons.material[:search]).props["icon"]
      wire << Ruflet::DSL.icon(icon: "settings").props["icon"]
      wire << Ruflet::DSL.icon(icon: Ruflet::Icons::ACCESS_ALARM).props["icon"]
      print JSON.generate(
        "wire" => wire,
        "cupertino_module_loaded" => !Ruflet.autoload?(:CupertinoIcons),
        "cupertino_table_loaded" => Ruflet::CupertinoIconLookup.instance_variable_defined?(:@icon_map)
      )
    RUBY

    assert(result["wire"].all? { |codepoint| codepoint & 0xF0000 == MATERIAL_SET }, result["wire"].inspect)
    refute result["cupertino_module_loaded"], "Ruflet::CupertinoIcons was loaded by Material-only code"
    refute result["cupertino_table_loaded"], "the Cupertino icon table was parsed by Material-only code"
  end

  # Single-name lookups answer from the compiled map; the constant-name index
  # (thousands of interned symbols, the cost the deferral exists to avoid) is
  # only for whole-table callers.
  def test_single_name_lookups_do_not_build_the_constant_index
    assert_equal "false,false", run_fresh(<<~RUBY)
      Ruflet::MaterialIcons[:add]
      Ruflet::Icons.material["home"]
      Ruflet::Icons::HOUSE_FILL
      Ruflet::CupertinoIcons[:house]
      print [Ruflet::MaterialIcons, Ruflet::CupertinoIcons].map { |set| set.instance_variable_defined?(:@icons) }.join(",")
    RUBY
  end

  def test_each_icon_set_file_loads_without_the_other
    { "material" => "cupertino", "cupertino" => "material" }.each do |set, other|
      loaded = run_fresh(<<~RUBY, preamble: false).split("\n")
        require "ruflet_ui/ruflet/icons/#{set}/#{set}_icons"
        Ruflet::#{set.capitalize}Icons::ADD
        print $LOADED_FEATURES.grep(%r{/ruflet_ui/}).join("\\n")
      RUBY
      refute_empty loaded, set
      assert_empty loaded.grep(/#{other}/), "loading the #{set} icons also loaded: #{loaded.grep(/#{other}/).inspect}"
    end
  end

  def test_each_control_family_loads_without_the_other
    { "materials" => "cupertinos", "cupertinos" => "materials" }.each do |family, other|
      loaded = run_fresh(<<~RUBY, preamble: false).split("\n")
        require "ruflet_protocol"
        require "ruflet_ui/ruflet/control"
        require "ruflet_ui/ruflet/ui/controls/#{family}/ruflet_controls"
        print $LOADED_FEATURES.grep(%r{/ui/controls/}).join("\\n")
      RUBY
      refute_empty loaded.grep(%r{/#{family}/}), family
      assert_empty loaded.grep(%r{/#{other}/}), "loading the #{family} controls also loaded: #{loaded.grep(%r{/#{other}/}).inspect}"
    end
  end

  private

  # A subprocess, so icons referenced by other tests in this process cannot
  # mask what a fresh boot loads.
  def run_fresh(body, preamble: true)
    script = +"$LOAD_PATH.unshift #{CORE_LIB.inspect}\nrequire \"json\"\n"
    script << "require \"ruflet_core\"\n" if preamble
    script << body
    output, errors, status = Open3.capture3(RbConfig.ruby, "-e", script)
    assert status.success?, "subprocess failed:\n#{output}#{errors}"
    output
  end
end
