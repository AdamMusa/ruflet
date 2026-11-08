#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes packages/ruflet/lib/ruflet/cli/template_surface_revisions.rb: for each
# wire type this checkout's control and service registries can send, and each
# bundled extension package, the first ruflet-template revision that ships it.
# `ruflet build`, `ruflet run` and `ruflet doctor` read the table to name the
# template an app needs (CRIT-04).
#
# A template's tool/conformance/ruflet_control_surface.json lists the wire types
# it renders (a snapshot of ruflet_core's registries when it was synced).
# Templates older than the first one with that file are not checked, so the
# table lists only what arrived after it; a wire type or package no revision
# ships yet is listed with nil.
#
#   ruby tools/template_surface_revisions.rb --template-repo ../ruflet-template \
#     [--ref origin/main] [--ref origin/<sync branch>]      # write the table
#   ruby tools/template_surface_revisions.rb --offline       # registries changed, no clone at hand
#   ruby tools/template_surface_revisions.rb --check [...]   # fail when the table is stale
#
# --offline keeps every revision already in the table and adds new wire types
# with nil, so a control PR can update it without a template clone; rerun with
# --template-repo once a template ships them.

require "json"
require "open3"
require "optparse"

$LOAD_PATH.unshift(File.expand_path("../packages/ruflet_core/lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../packages/ruflet/lib", __dir__))

module TemplateSurfaceRevisions
  REPOSITORY = "AdamMusa/ruflet-template"
  TEMPLATE_DIR = "templates/ruflet_flutter_template"
  SURFACE_PATH = "tool/conformance/ruflet_control_surface.json"
  OUTPUT = File.expand_path("../packages/ruflet/lib/ruflet/cli/template_surface_revisions.rb", __dir__)

  module_function

  # wire type => { "family" =>, "dsl_names" => [...] }, from the same registries
  # the template's generate_ruflet_control_surface.rb reads.
  def live_wire_types
    require "ruflet_core"
    surfaces = {
      "visual" => Ruflet::UI::Controls::RufletControls::CLASS_MAP,
      "service" => Ruflet::UI::Services::RufletServices::CLASS_MAP
    }
    wire_types = {}
    surfaces.each do |family, controls|
      controls.each do |dsl_name, klass|
        wire = klass.const_defined?(:WIRE) ? klass::WIRE : klass::TYPE
        entry = wire_types[wire] ||= { "family" => family, "dsl_names" => [] }
        entry["dsl_names"] << dsl_name
      end
    end
    wire_types.each_value { |entry| entry["dsl_names"].sort! }
    wire_types
  end

  def live_packages
    require "ruflet/cli"
    Ruflet::CLI::NewCommand::CLIENT_EXTENSION_MAP.values.map { |entry| entry[:package] }.uniq.sort
  end

  def git(repo, *args)
    out, err, status = Open3.capture3("git", "-C", repo, *args)
    abort "git #{args.join(' ')} failed: #{err}" unless status.success?
    out
  end

  # Oldest first, over the union of the refs' histories, every commit that
  # touched the surface file or a bundled package.
  def template_history(repo, refs)
    paths = ["#{TEMPLATE_DIR}/#{SURFACE_PATH}", "#{TEMPLATE_DIR}/ruflet_packages"]
    git(repo, "rev-list", "--reverse", "--topo-order", *refs, "--", *paths).split
  end

  # Like git, but nil when the object does not exist at that commit.
  def git_optional(repo, *args)
    out, _err, status = Open3.capture3("git", "-C", repo, *args)
    status.success? ? out : nil
  end

  def surface_wire_types(repo, commit)
    text = git_optional(repo, "show", "#{commit}:#{TEMPLATE_DIR}/#{SURFACE_PATH}")
    text && JSON.parse(text).fetch("entries").map { |entry| entry.fetch("wire_type") }.uniq
  end

  def surface_present?(repo, commit)
    !git_optional(repo, "cat-file", "-e", "#{commit}:#{TEMPLATE_DIR}/#{SURFACE_PATH}").nil?
  end

  # Templates before the ruflet_packages/ layout have none.
  def packages_at(repo, commit)
    git_optional(repo, "ls-tree", "--name-only", "#{commit}:#{TEMPLATE_DIR}/ruflet_packages").to_s.split
  end

  def from_history(repo, refs)
    commits = template_history(repo, refs)
    baseline = commits.find { |commit| surface_present?(repo, commit) }
    abort "no revision of #{refs.join(', ')} has #{SURFACE_PATH}" unless baseline

    wire_first = {}
    package_first = {}
    seen_baseline = false
    commits.each do |commit|
      seen_baseline ||= commit == baseline
      next unless seen_baseline

      (surface_wire_types(repo, commit) || []).each { |wire| wire_first[wire] ||= commit }
      packages_at(repo, commit).each { |package| package_first[package] ||= commit }
    end
    { baseline: baseline, wire_first: wire_first, package_first: package_first }
  end

  def table(history)
    baseline = history[:baseline]
    wire_types = live_wire_types.sort.filter_map do |wire, entry|
      revision = history[:wire_first][wire]
      next if revision == baseline

      [wire, entry["family"], entry["dsl_names"], revision]
    end
    packages = live_packages.filter_map do |package|
      revision = history[:package_first][package]
      next if revision == baseline

      [package, revision]
    end
    { baseline: baseline, wire_types: wire_types, packages: packages }
  end

  # The history the current table was generated from: baseline entries map
  # to the baseline revision, later ones to theirs.
  def offline_history
    require "ruflet/cli/template_surface_revisions"
    current = Ruflet::CLI::TemplateSurface
    baseline = current::BASELINE_REVISION
    wire_first = current::BASELINE_WIRE_TYPES.to_h { |wire| [wire, baseline] }
    current::WIRE_TYPES.each { |wire, (_family, _names, revision)| wire_first[wire] = revision if revision }
    package_first = current::BASELINE_PACKAGES.to_h { |package| [package, baseline] }
    current::EXTENSION_PACKAGES.each { |package, revision| package_first[package] = revision if revision }
    { baseline: baseline, wire_first: wire_first, package_first: package_first }
  end

  def render(table, history)
    baseline_wires = history[:wire_first].select { |_wire, revision| revision == table[:baseline] }.keys.sort
    baseline_packages = history[:package_first].select { |_package, revision| revision == table[:baseline] }.keys.sort
    lines = []
    lines << "# frozen_string_literal: true"
    lines << ""
    lines << "# Generated by tools/template_surface_revisions.rb from #{REPOSITORY}; do not edit."
    lines << "# Regenerate when ruflet_core gains a control or service, or a template ships one."
    lines << "module Ruflet"
    lines << "  module CLI"
    lines << "    module TemplateSurface"
    lines << "      # The first template revision with #{SURFACE_PATH}."
    lines << "      # Older templates are not checked."
    lines << "      BASELINE_REVISION = #{table[:baseline].inspect}"
    lines << ""
    lines << "      # Wire types and bundled packages every checked template has."
    lines << "      BASELINE_WIRE_TYPES = #{word_list(baseline_wires, 6)}.freeze"
    lines << "      BASELINE_PACKAGES = #{word_list(baseline_packages, 6)}.freeze"
    lines << ""
    lines << "      # Wire types added since: [family, DSL names, first template revision"
    lines << "      # that renders it (nil: none yet)]."
    lines << "      WIRE_TYPES = {"
    table[:wire_types].each do |wire, family, names, revision|
      lines << "        #{wire.inspect} => [#{family.inspect}, %w[#{names.join(' ')}].freeze, #{revision.inspect}].freeze,"
    end
    lines[-1] = lines[-1].delete_suffix(",") unless table[:wire_types].empty?
    lines << "      }.freeze"
    lines << ""
    lines << "      # Bundled extension packages added since: first template revision"
    lines << "      # with ruflet_packages/<package> (nil: none yet)."
    lines << "      EXTENSION_PACKAGES = {"
    table[:packages].each { |package, revision| lines << "        #{package.inspect} => #{revision.inspect}," }
    lines[-1] = lines[-1].delete_suffix(",") unless table[:packages].empty?
    lines << "      }.freeze"
    lines << "    end"
    lines << "  end"
    lines << "end"
    "#{lines.join("\n")}\n"
  end

  def word_list(words, indent)
    return "[]" if words.empty?

    rows = []
    row = +""
    words.each do |word|
      if row.length + word.length + 1 > 100 - indent - 2
        rows << row.strip
        row = +""
      end
      row << " " << word
    end
    rows << row.strip unless row.strip.empty?
    pad = " " * (indent + 2)
    "%w[\n#{rows.map { |r| "#{pad}#{r}" }.join("\n")}\n#{' ' * indent}]"
  end

  def main(argv)
    options = { refs: [], repo: nil, offline: false, check: false, out: OUTPUT }
    OptionParser.new do |o|
      o.on("--template-repo PATH") { |value| options[:repo] = File.expand_path(value) }
      o.on("--ref REF") { |value| options[:refs] << value }
      o.on("--offline") { options[:offline] = true }
      o.on("--check") { options[:check] = true }
      o.on("--out PATH") { |value| options[:out] = File.expand_path(value) }
    end.parse!(argv)

    history =
      if options[:offline] || options[:repo].nil?
        abort "pass --template-repo PATH, or --offline" unless options[:offline] || options[:check]
        offline_history
      else
        options[:refs] << "origin/main" if options[:refs].empty?
        from_history(options[:repo], options[:refs])
      end
    content = render(table(history), history)

    if options[:check]
      current = File.file?(options[:out]) ? File.read(options[:out]) : ""
      if current == content
        puts "#{options[:out]} is current"
        return 0
      end
      warn "#{options[:out]} is stale; regenerate it with ruby tools/template_surface_revisions.rb"
      return 1
    end

    File.write(options[:out], content)
    written = table(history)
    puts "wrote #{options[:out]} (#{written[:wire_types].length} wire types, #{written[:packages].length} packages)"
    0
  end
end

exit TemplateSurfaceRevisions.main(ARGV.dup) if $PROGRAM_NAME == __FILE__
