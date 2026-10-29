#!/usr/bin/env ruby
# frozen_string_literal: true

# Exports the Ruby control surface as JSON: every DSL name the control
# factory resolves (and every service), its wire type, the keywords it
# accepts, whether it is the canonical name of its wire type, and per wire
# type the union of keywords of every class that sends it.
#
# The ruflet repo owns this contract. The engine's control-core contract test
# reads a checked-in copy to prove each shared core declares exactly what
# Ruby can send (engine: tool/sync_ruby_surface.rb), and the template's
# conformance check can read the same file.
#
#   ruby tools/control_surface.rb              # print JSON
#   ruby tools/control_surface.rb --out PATH   # write PATH
#   ruby tools/control_surface.rb --check PATH # fail when PATH is stale

require "json"

$LOAD_PATH.unshift(File.expand_path("../packages/ruflet_core/lib", __dir__))
require "ruflet_core"

module RufletControlSurface
  CONTRACT_VERSION = 2

  module_function

  def factory = Ruflet::UI::ControlFactory
  def services = Ruflet::UI::Services::RufletServices::CLASS_MAP

  # The visual names are what the factory resolves (registry plus the
  # canonical platform contracts it merges last); services keep their own
  # family even when a visual name shares the class.
  def visual_names
    visual = Ruflet::UI::Controls::RufletControls::CLASS_MAP.keys +
             Ruflet::UI::PlatformControlContracts::CLASS_MAP.keys
    factory::CLASS_MAP.keys & visual
  end

  def wire_type(klass)
    klass.const_defined?(:WIRE) ? klass::WIRE : klass::TYPE
  end

  # Exactly what ControlFactory.build(dsl_name, ...) accepts and can put on
  # the wire (COMMON_ATTRIBUTES are listed once at the top level).
  def keywords(dsl_name, klass)
    names = factory.constructor_keywords(klass) +
            factory::ATTRIBUTE_OVERRIDES.fetch(dsl_name, [])
    names.map(&:to_s).uniq.sort
  end

  def snake_case(name)
    name.gsub(/([a-z\d])([A-Z])/, "\\1_\\2").downcase
  end

  def raw_entries
    visual = visual_names.map { |name| [name, "visual", factory::CLASS_MAP.fetch(name)] }
    service = services.map { |name, klass| [name, "service", klass] }
    (visual + service).map do |name, family, klass|
      {
        "dsl_name" => name,
        "family" => family,
        "ruby_class" => klass.name,
        "wire_type" => wire_type(klass),
        "keywords" => keywords(name, klass)
      }
    end
  end

  # The canonical DSL name of a wire type is its snake_case spelling
  # (`AlertDialog` -> `alert_dialog`); every other name is an alias of it.
  def canonical_names(entries)
    entries.group_by { |entry| entry.fetch("wire_type") }.to_h do |wire, group|
      names = group.map { |entry| entry.fetch("dsl_name") }.uniq.sort
      preferred = snake_case(wire)
      [wire, names.include?(preferred) ? preferred : (names.find { |n| n.include?("_") } || names.first)]
    end
  end

  def build
    entries = raw_entries
    canonical = canonical_names(entries)
    entries.each do |entry|
      name = canonical.fetch(entry.fetch("wire_type"))
      entry["canonical"] = entry.fetch("dsl_name") == name
      entry["alias_of"] = entry["canonical"] ? nil : name
    end
    entries.sort_by! { |entry| [entry.fetch("family"), entry.fetch("dsl_name")] }

    wire_types = entries.group_by { |entry| entry.fetch("wire_type") }.sort.to_h do |wire, group|
      [wire, {
        "canonical" => canonical.fetch(wire),
        "family" => group.any? { |e| e.fetch("family") == "visual" } ? "visual" : "service",
        "dsl_names" => group.map { |e| e.fetch("dsl_name") }.uniq.sort,
        "keywords" => group.flat_map { |e| e.fetch("keywords") }.uniq.sort
      }]
    end

    {
      "contract_version" => CONTRACT_VERSION,
      "source" => "Ruflet::UI::ControlFactory and service registries",
      "summary" => {
        "advertised_entries" => entries.length,
        "visual_entries" => entries.count { |e| e.fetch("family") == "visual" },
        "service_entries" => entries.count { |e| e.fetch("family") == "service" },
        "canonical_entries" => entries.count { |e| e.fetch("canonical") },
        "wire_types" => wire_types.length
      },
      # Accepted by every control and sent on the wire (`ref` stays in Ruby).
      "common_attributes" => (factory::COMMON_ATTRIBUTES.map(&:to_s) - ["ref"]).sort,
      "wire_types" => wire_types,
      "entries" => entries
    }
  end

  def generate
    "#{JSON.pretty_generate(build)}\n"
  end

  def run(argv, out: $stdout)
    if (index = argv.index("--check"))
      path = argv.fetch(index + 1) { abort "usage: --check PATH" }
      current = File.file?(path) ? File.read(path) : nil
      return true if current == generate

      warn "#{path} is stale. Regenerate it with: ruby #{__FILE__} --out #{path}"
      false
    elsif (index = argv.index("--out"))
      path = argv.fetch(index + 1) { abort "usage: --out PATH" }
      File.write(path, generate)
      out.puts "Wrote #{path}: #{JSON.generate(build.fetch("summary"))}"
      true
    else
      out.write(generate)
      true
    end
  end
end

exit(RufletControlSurface.run(ARGV) ? 0 : 1) if $PROGRAM_NAME == __FILE__
