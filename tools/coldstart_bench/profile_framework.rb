# frozen_string_literal: true
#
# Reproduces the concatenated framework source that ruflet-framework's
# mrbgem.rake feeds to mrbc, but emits it as one file per feature plus a
# manifest, so the boot cost can be attributed to individual framework files
# rather than to "mrb_open" as a whole.
#
# The feature ordering here must match mrbgem.rake's, otherwise features load
# against constants that do not exist yet and the timings measure failures.
#
# Usage: ruby profile_framework.rb <output_dir>

require "json"
require "fileutils"

ROOT = File.expand_path("../..", __dir__)
OUT = ARGV[0] or abort "usage: profile_framework.rb <output_dir>"

lib_roots = [
  File.join(ROOT, "packages/ruflet_core/lib"),
  File.join(ROOT, "packages/ruflet_server/lib")
]

features = {}
lib_roots.each do |lib_root|
  Dir.glob(File.join(lib_root, "**/*.rb")).sort.each do |path|
    feature = path.delete_prefix("#{lib_root}/").delete_suffix(".rb")
    features[feature] = path
  end
end

ordered = []
feature_for_path = features.invert
visiting = {}
visit = lambda do |feature|
  return if ordered.include?(feature)
  return if visiting[feature]

  path = features[feature]
  return unless path

  visiting[feature] = true
  File.foreach(path, encoding: "UTF-8") do |line|
    if (match = line.match(/^\s*require\s+["']([^"']+)["']/))
      visit.call(match[1])
    elsif (match = line.match(/^\s*require_relative\s+["']([^"']+)["']/))
      relative = File.expand_path(match[1], File.dirname(path))
      relative += ".rb" unless relative.end_with?(".rb")
      dependency = feature_for_path[relative]
      visit.call(dependency) if dependency
    end
  end
  visiting.delete(feature)
  ordered << feature
end

visit.call("ruflet_ui/ruflet/control")
visit.call("ruflet")
visit.call("ruflet_server")
features.each_key { |feature| visit.call(feature) }

foundation = %w[
  ruflet_protocol/ruflet/protocol
  ruflet_protocol
  ruflet_ui/ruflet/icons/material_icon_lookup
  ruflet_ui/ruflet/icons/cupertino_icon_lookup
  ruflet_ui/ruflet/icon_data
  ruflet_ui/ruflet/control
]
ordered = foundation + ordered.reject { |feature| foundation.include?(feature) }

FileUtils.rm_rf(OUT)
FileUtils.mkdir_p(OUT)

manifest = []
ordered.each_with_index do |feature, index|
  source =
    case feature
    when "ruflet_ui/ruflet/icons/material_icon_lookup"
      icons = JSON.parse(File.read(File.join(ROOT, "packages/ruflet_core/lib/ruflet_ui/ruflet/icons/material/icons.json")))
                  .transform_keys { |key| key.to_s.upcase }
      "module Ruflet; module MaterialIconLookup; COMPILED_ICON_MAP = #{icons.inspect}.freeze; end; end\n" +
        File.binread(features.fetch(feature))
    when "ruflet_ui/ruflet/icons/cupertino_icon_lookup"
      icons = JSON.parse(File.read(File.join(ROOT, "packages/ruflet_core/lib/ruflet_ui/ruflet/icons/cupertino/cupertino_icons.json")))
                  .transform_keys { |key| key.to_s.upcase }
      "module Ruflet; module CupertinoIconLookup; COMPILED_ICON_MAP = #{icons.inspect}.freeze; end; end\n" +
        File.binread(features.fetch(feature))
    else
      File.binread(features.fetch(feature))
    end

  name = format("%03d_%s.rb", index, feature.gsub("/", "__"))
  File.binwrite(File.join(OUT, name), source)
  manifest << name
end

File.write(File.join(OUT, "manifest.txt"), manifest.join("\n") + "\n")
warn "wrote #{manifest.length} features to #{OUT}"
