# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "stringio"
require "tmpdir"
require_relative "../../../tools/control_surface"

class ControlSurfaceExportTest < Minitest::Test
  def setup
    @surface = RufletControlSurface.build
    @entries = @surface.fetch("entries")
  end

  def test_contract_version_and_summary_count_what_is_exported
    summary = @surface.fetch("summary")

    assert_equal 2, @surface.fetch("contract_version")
    assert_equal @entries.length, summary.fetch("advertised_entries")
    assert_equal summary.fetch("advertised_entries"),
                 summary.fetch("visual_entries") + summary.fetch("service_entries")
    assert_equal @surface.fetch("wire_types").length, summary.fetch("wire_types")
  end

  def test_every_name_the_factory_resolves_is_an_entry
    visual = @entries.select { |e| e.fetch("family") == "visual" }.map { |e| e.fetch("dsl_name") }
    services = @entries.select { |e| e.fetch("family") == "service" }.map { |e| e.fetch("dsl_name") }
    factory_names = Ruflet::UI::ControlFactory::CLASS_MAP.keys

    assert_empty factory_names - visual - services
    assert_equal Ruflet::UI::Services::RufletServices::CLASS_MAP.keys.sort, services.sort
    assert_includes visual, "picker", "contract-only names the factory builds are exported"
  end

  def test_entries_report_the_class_the_factory_builds
    switch = entry("visual", "switch")

    assert_equal Ruflet::UI::ControlFactory::CLASS_MAP.fetch("switch").name, switch.fetch("ruby_class")
    assert_equal "Switch", switch.fetch("wire_type")
    assert_includes switch.fetch("keywords"), "hover_color"
    assert_includes switch.fetch("keywords"), "active_thumb_image"
  end

  def test_aliases_point_at_the_canonical_name_of_their_wire_type
    switch = entry("visual", "switch")
    alias_entry = entry("visual", "cupertino_switch")
    spelling = entry("visual", "alertdialog")

    assert switch.fetch("canonical")
    assert_nil switch.fetch("alias_of")
    refute alias_entry.fetch("canonical")
    assert_equal "switch", alias_entry.fetch("alias_of")
    assert_equal "alert_dialog", spelling.fetch("alias_of")

    by_name = @entries.group_by { |e| e.fetch("dsl_name") }
    @entries.reject { |e| e.fetch("canonical") }.each do |e|
      target = by_name.fetch(e.fetch("alias_of")).first
      assert target.fetch("canonical"), "#{e.fetch("dsl_name")} aliases a non-canonical name"
      assert_equal e.fetch("wire_type"), target.fetch("wire_type"), e.fetch("dsl_name")
    end
  end

  def test_wire_types_carry_the_union_of_every_class_sending_them
    switch = @surface.fetch("wire_types").fetch("Switch")

    assert_equal "switch", switch.fetch("canonical")
    assert_equal %w[cupertino_switch cupertinoswitch switch], switch.fetch("dsl_names")
    expected = %w[cupertino_switch switch].flat_map { |name| entry("visual", name).fetch("keywords") }.uniq.sort
    assert_equal expected, switch.fetch("keywords")
    assert_includes switch.fetch("keywords"), "on_label_color"
    @surface.fetch("wire_types").each do |wire, data|
      assert_includes data.fetch("dsl_names"), data.fetch("canonical"), wire
    end
  end

  def test_keywords_cover_classes_without_a_keywords_constant
    group = @surface.fetch("wire_types").fetch("RadioGroup")

    assert_includes group.fetch("keywords"), "content"
    assert_includes group.fetch("keywords"), "on_change"
  end

  def test_common_attributes_are_the_wire_ones
    assert_equal %w[flip transform], @surface.fetch("common_attributes")
  end

  def test_out_and_check_round_trip
    Dir.mktmpdir do |dir|
      path = File.join(dir, "surface.json")
      out = StringIO.new

      refute quietly { RufletControlSurface.run(["--check", path], out: out) }
      assert RufletControlSurface.run(["--out", path], out: out)
      assert quietly { RufletControlSurface.run(["--check", path], out: out) }
      assert_equal RufletControlSurface.generate, File.read(path)

      File.write(path, File.read(path).sub("\"contract_version\": 2", "\"contract_version\": 1"))
      refute quietly { RufletControlSurface.run(["--check", path], out: out) }
    end
  end

  private

  def entry(family, name)
    @entries.find { |e| e.fetch("family") == family && e.fetch("dsl_name") == name } ||
      flunk("missing #{family} entry #{name}")
  end

  def quietly
    original = $stderr
    $stderr = StringIO.new
    yield
  ensure
    $stderr = original
  end
end
