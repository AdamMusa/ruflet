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
# Templates older than the first one with that file are not checked. A wire
# type or package no revision ships yet is listed with nil.
#
# Wire types are dated from BASELINE (--baseline), the first revision whose
# surface lists every wire type its renderers handle. The surfaces before it
# (0c02f475 to 32cd174) were taken from an older ruflet_core and leave out
# controls their Dart already rendered (Lottie, Rive, CodeEditor, the map, ads,
# chart, DataTable2 and color picker controls, Picker, TimerPicker,
# ActionSheet, ContextMenuAction), so a first listing there is not a first
# renderer. Every wire type of the baseline surface counts as rendered by every
# checked template. Bundled packages are read from ruflet_packages/ itself, so
# they are dated from the first template with a surface file.
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
  # "Remove the Swift rendering engine": its surface was regenerated from the
  # ruflet_core its renderers match.
  BASELINE = "19ac4c9eb87d9ea1ce1083c2cafc74354cbb56d5"

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

  def ancestor?(repo, ancestor, commit)
    _out, _err, status = Open3.capture3("git", "-C", repo, "merge-base", "--is-ancestor", ancestor, commit)
    status.success?
  end

  def from_history(repo, refs, baseline: BASELINE)
    commits = template_history(repo, refs)
    first_surface = commits.find { |commit| surface_present?(repo, commit) }
    abort "no revision of #{refs.join(', ')} has #{SURFACE_PATH}" unless first_surface

    baseline = git(repo, "rev-parse", "--verify", "#{baseline}^{commit}").strip
    unless surface_present?(repo, baseline) && refs.any? { |ref| ancestor?(repo, baseline, ref) }
      abort "baseline #{baseline} has no #{SURFACE_PATH} or is not in #{refs.join(', ')}"
    end

    wire_first = surface_wire_types(repo, baseline).to_h { |wire| [wire, baseline] }
    package_first = {}
    seen_first_surface = false
    commits.each do |commit|
      seen_first_surface ||= commit == first_surface
      next unless seen_first_surface

      packages_at(repo, commit).each { |package| package_first[package] ||= commit }
      next if commit == baseline || !ancestor?(repo, baseline, commit)

      (surface_wire_types(repo, commit) || []).each { |wire| wire_first[wire] ||= commit }
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
    packages = live_packages.map { |package| [package, history[:package_first][package]] }
    { baseline: baseline, wire_types: wire_types, packages: packages }
  end

  # The history the current table was generated from: baseline wire types map
  # to the baseline revision, later ones to theirs.
  def offline_history
    require "ruflet/cli/template_surface_revisions"
    current = Ruflet::CLI::TemplateSurface
    baseline = current::BASELINE_REVISION
    wire_first = current::BASELINE_WIRE_TYPES.to_h { |wire| [wire, baseline] }
    current::WIRE_TYPES.each { |wire, (_family, _names, revision)| wire_first[wire] = revision if revision }
    package_first = current::EXTENSION_PACKAGES.compact
    { baseline: baseline, wire_first: wire_first, package_first: package_first }
  end

  def render(table, history)
    baseline_wires = history[:wire_first].select { |_wire, revision| revision == table[:baseline] }.keys.sort
    lines = []
    lines << "# frozen_string_literal: true"
    lines << ""
    lines << "# Generated by tools/template_surface_revisions.rb from #{REPOSITORY}; do not edit."
    lines << "# Regenerate when ruflet_core gains a control or service, or a template ships one."
    lines << "module Ruflet"
    lines << "  module CLI"
    lines << "    module TemplateSurface"
    lines << "      # The first template revision whose #{SURFACE_PATH}"
    lines << "      # lists every wire type it renders. Templates without that file are not"
    lines << "      # checked."
    lines << "      BASELINE_REVISION = #{table[:baseline].inspect}"
    lines << ""
    lines << "      # Wire types counted as rendered by every checked template (older"
    lines << "      # surfaces leave out some that their renderers handle)."
    lines << "      BASELINE_WIRE_TYPES = #{word_list(baseline_wires, 6)}.freeze"
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
    lines << "      # Bundled extension packages: first template revision with a surface file"
    lines << "      # and ruflet_packages/<package> (nil: none yet)."
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
    options = { refs: [], repo: nil, offline: false, check: false, out: OUTPUT, baseline: BASELINE }
    OptionParser.new do |o|
      o.on("--template-repo PATH") { |value| options[:repo] = File.expand_path(value) }
      o.on("--baseline REV") { |value| options[:baseline] = value }
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
        from_history(options[:repo], options[:refs], baseline: options[:baseline])
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
