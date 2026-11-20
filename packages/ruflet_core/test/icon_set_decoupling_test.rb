# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"
require "yaml"

# The Material and Cupertino icon sets: what each lookup returns, what it
# sends on the wire, and what it loads.
#
# 101 names (ADD, HOME, ...) are in both sets with different codepoints.
# Every published ruflet_core (0.0.15 through 0.0.23) sends Material's
# codepoint for all of them, whichever set the name was taken from:
# CupertinoIcons::ADD sends 65604, not Cupertino's 131072. Apps show that
# glyph today, so these tests pin it. Changing it is a decision for the
# owner, not a side effect of a lookup change.
class RufletIconSetDecouplingTest < Minitest::Test
  CORE_LIB = File.expand_path("../lib", __dir__)

  # What every published ruflet_core from 0.0.15 to 0.0.23 sends.
  PUBLISHED_WIRE = {
    "CupertinoIcons::ADD" => 65_604,
    "CupertinoIcons::HOME" => 69_217,
    "CupertinoIcons::HOUSE_FILL" => 131_732,
    "Icons.cupertino[:add]" => 65_604,
    "MaterialIcons::CLASS" => 66_925
  }.freeze

  def test_published_codepoints_are_unchanged
    values = {
      "CupertinoIcons::ADD" => Ruflet::CupertinoIcons::ADD,
      "CupertinoIcons::HOME" => Ruflet::CupertinoIcons::HOME,
      "CupertinoIcons::HOUSE_FILL" => Ruflet::CupertinoIcons::HOUSE_FILL,
      "Icons.cupertino[:add]" => Ruflet::Icons.cupertino[:add],
      "MaterialIcons::CLASS" => Ruflet::MaterialIcons::CLASS
    }

    values.each do |label, value|
      assert_equal PUBLISHED_WIRE.fetch(label), Ruflet::DSL.icon(icon: value).props["icon"], label
      assert_equal PUBLISHED_WIRE.fetch(label), Ruflet::DSL.cupertino_button("x", icon: value).props["icon"], label
    end
  end

  def test_shared_names_send_the_material_codepoint_from_every_entry_point
    material = Ruflet::MaterialIconLookup.icon_map
    shared = material.keys & Ruflet::CupertinoIconLookup.icon_map.keys
    assert_equal 101, shared.size

    shared.each do |key|
      name = key.downcase
      constant = key.to_sym
      entry_points = {
        "CupertinoIcons::#{key}" => Ruflet::CupertinoIcons.const_get(constant),
        "CupertinoIcons[#{name.inspect}]" => Ruflet::CupertinoIcons[name],
        "CupertinoIcons[:#{name}]" => Ruflet::CupertinoIcons[name.to_sym],
        "Icons.cupertino[#{name.inspect}]" => Ruflet::Icons.cupertino[name],
        "IconData.new(CupertinoIcons::#{key})" => Ruflet::IconData.new(Ruflet::CupertinoIcons.const_get(constant)),
        "MaterialIcons::#{key}" => Ruflet::MaterialIcons.const_get(constant),
        "Icons::#{key}" => Ruflet::Icons.const_get(constant),
        name.inspect => name
      }

      entry_points.each do |label, value|
        [:icon, :button, :cupertino_button].each do |family|
          control = family == :icon ? Ruflet::DSL.icon(icon: value) : Ruflet::DSL.public_send(family, "x", icon: value)
          assert_equal material.fetch(key), control.props["icon"], "#{family}(icon: #{label})"
        end
      end
    end
  end

  def test_page_update_sends_the_published_codepoint
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
    assert_equal PUBLISHED_WIRE.fetch("CupertinoIcons::ADD"), patch[3]
  end

  def test_whole_set_accessors_send_the_published_codepoints
    material = Ruflet::MaterialIconLookup.icon_map
    cupertino = Ruflet::CupertinoIconLookup.icon_map

    names = Ruflet::CupertinoIcons.all
    assert_equal cupertino.size, names.size
    names.each do |name|
      expected = material[name.upcase] || cupertino.fetch(name.upcase)
      assert_equal expected, Ruflet::DSL.icon(icon: name).props["icon"], "CupertinoIcons.all: #{name}"
      assert_equal expected, Ruflet::DSL.icon(icon: Ruflet::IconData.new(name)).props["icon"], "IconData(#{name})"
    end
    assert_equal names, Ruflet::Icons.cupertino.all

    10.times do
      name = Ruflet::CupertinoIcons.random
      assert_includes names, name
      assert_equal material[name.upcase] || cupertino.fetch(name.upcase), Ruflet::DSL.icon(icon: name).props["icon"]
    end
  end

  def test_set_names_are_plain_mutable_strings
    values = {
      "MaterialIcons::HOME" => Ruflet::MaterialIcons::HOME,
      "MaterialIcons[:home]" => Ruflet::MaterialIcons[:home],
      "CupertinoIcons::ADD" => Ruflet::CupertinoIcons::ADD,
      "CupertinoIcons[:add]" => Ruflet::CupertinoIcons[:add],
      "Icons.cupertino[:add]" => Ruflet::Icons.cupertino[:add],
      "Icons::HOUSE_FILL" => Ruflet::Icons::HOUSE_FILL,
      "MaterialIcons.all.first" => Ruflet::MaterialIcons.all.first,
      "CupertinoIcons.all.first" => Ruflet::CupertinoIcons.all.first,
      "CupertinoIcons.random" => Ruflet::CupertinoIcons.random
    }

    values.each do |label, value|
      assert_instance_of String, value, label
      refute_predicate value, :frozen?, label
    end
    assert_equal "home_filled", Ruflet::MaterialIcons[:home] << "_filled"
    assert_equal "---\nicon: home\nadd: add\n",
                 YAML.dump("icon" => Ruflet::MaterialIcons::HOME, "add" => Ruflet::CupertinoIcons[:add])
    assert_equal({ "icon" => "home" }, YAML.safe_load(YAML.dump("icon" => Ruflet::MaterialIcons::HOME)))
    assert_instance_of String, Marshal.load(Marshal.dump(Ruflet::CupertinoIcons::ADD))
  end

  # Ruflet::Icons[] is left exactly as main and 0.0.23 have it, including the
  # result's type depending on whether the constant was referenced first.
  def test_icons_lookup_keeps_its_published_results
    result = JSON.parse(run_fresh(<<~RUBY))
      cold = Ruflet::Icons[:home]
      arrow = begin
        Ruflet::Icons["arrow back"]
        "no error"
      rescue NameError => e
        e.class.name
      end
      Ruflet::MaterialIcons::HOME
      Ruflet::Icons::CLASS
      print JSON.generate(
        "cold" => [cold.class.name, cold.value, cold == "HOME", Ruflet::DSL.icon(icon: cold).props["icon"]],
        "warm" => [Ruflet::Icons[:home].class.name, Ruflet::Icons[:home]],
        "class" => [:class, "CLASS", "Class"].map { |name| Ruflet::DSL.icon(icon: Ruflet::Icons[name]).props["icon"] },
        "arrow back" => arrow
      )
    RUBY

    assert_equal ["Ruflet::IconData", "home", true, 69_217], result["cold"]
    assert_equal ["String", "home"], result["warm"]
    assert_equal [66_925, 66_925, 66_925], result["class"]
    assert_equal "NameError", result["arrow back"]
  end

  # The single-name lookups now try the compiled map before the constant-name
  # index. That must give the answer the index-first order gave (the same
  # text, encoding and frozenness), for every name in both sets and the
  # spellings apps use.
  def test_single_name_lookups_give_the_index_first_answer
    sets = [
      [Ruflet::MaterialIcons, Ruflet::MaterialIconLookup],
      [Ruflet::CupertinoIcons, Ruflet::CupertinoIconLookup]
    ]
    keys = sets.flat_map { |_, lookup| lookup.icon_map.keys }.uniq
    inputs = keys.flat_map do |key|
      name = key.downcase
      [name, name.to_sym, name.b, key, Ruflet::IconNames.constant_for(key), name.tr("_", " "), "icons.#{name}"]
    end
    inputs += ["class", "CLASS", "Class", :class, :class_, "", " home ", "0x10044", "65604", 65_604, "not_an_icon"]

    sets.each do |set, lookup|
      # The map-first answer relies on no two map keys sharing a constant name.
      assert_equal lookup.icon_map.size, set.icons.size, "#{set}: two icons share a constant name"
      inputs.each do |input|
        icon = set.icons[input.to_s.upcase.to_sym]
        expected = icon.nil? ? (lookup.canonical_name_for(input) || input.to_s) : icon.to_s.downcase
        actual = set[input]
        assert_equal [expected, expected.encoding, expected.frozen?], [actual, actual.encoding, actual.frozen?],
                     "#{set}[#{input.inspect}]"
      end
    end

    material = Ruflet::MaterialIconLookup.icon_map
    cupertino = Ruflet::CupertinoIconLookup.icon_map
    constants = (Ruflet::MaterialIcons.icons.keys + Ruflet::CupertinoIcons.icons.keys).uniq
    constants.each do |constant|
      key = constant.to_s
      expected = if material.key?(key) then key.downcase
                 elsif Ruflet::MaterialIcons.icons.key?(constant) then Ruflet::MaterialIcons.icons[constant].downcase
                 elsif cupertino.key?(key) then key.downcase
                 else Ruflet::CupertinoIcons.icons.fetch(constant).downcase
                 end
      actual = Ruflet::Icons.const_get(constant)
      assert_equal [expected, expected.encoding], [actual, actual.encoding], "Icons::#{constant}"
    end
  end

  # Single-name lookups answer from the compiled map; the constant-name index
  # (a symbol per icon, the cost the deferral exists to avoid) is only for
  # whole-table callers and the one name that needs it, CLASS.
  def test_single_name_lookups_do_not_build_the_constant_index
    assert_equal ["false,false", "add home house_fill house"], run_fresh(<<~RUBY).split("|")
      found = [Ruflet::MaterialIcons[:add], Ruflet::Icons.material["home"], Ruflet::Icons::HOUSE_FILL, Ruflet::CupertinoIcons[:house]]
      built = [Ruflet::MaterialIcons, Ruflet::CupertinoIcons].map { |set| set.instance_variable_defined?(:@icons) }
      print built.join(","), "|", found.join(" ")
    RUBY
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

    lookup = Ruflet::MaterialIconLookup.icon_map
    assert_equal lookup.values_at("ADD", "HOME", "SEARCH", "SETTINGS", "ACCESS_ALARM"), result["wire"]
    refute result["cupertino_module_loaded"], "Ruflet::CupertinoIcons was loaded by Material-only code"
    refute result["cupertino_table_loaded"], "the Cupertino icon table was parsed by Material-only code"
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
