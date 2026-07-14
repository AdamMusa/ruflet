require "json"

MRuby::Gem::Specification.new("ruflet-framework") do |spec|
  spec.license = "MIT"
  spec.author = "Ruflet"
  spec.summary = "Precompiled Ruflet framework and server gems"
  root = File.expand_path("../../../..", __dir__)
  lib_roots = [
    File.join(root, "packages/ruflet_core/lib"),
    File.join(root, "packages/ruflet_server/lib")
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

  # Generated control registries reference Ruflet::Control without requiring
  # it themselves because normal CRuby loading establishes that invariant.
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

  combined = File.join(__dir__, "mrblib/10_framework.rb")
  thread_compat = File.join(__dir__, "mrblib/01_thread.rb")
  FileUtils.cp(File.join(root, "ruby_runtime/vm/stdlib/thread.rb"), thread_compat)
  File.open(combined, "wb") do |output|
    ordered.each do |feature|
      if feature == "ruflet_ui/ruflet/icons/material_icon_lookup"
        icon_path = File.join(root, "packages/ruflet_core/lib/ruflet_ui/ruflet/icons/material/icons.json")
        icon_map = JSON.parse(File.read(icon_path)).transform_keys { |key| key.to_s.upcase }
        output.write("module Ruflet; module MaterialIconLookup; COMPILED_ICON_MAP = #{icon_map.inspect}.freeze; end; end\n")
      elsif feature == "ruflet_ui/ruflet/icons/cupertino_icon_lookup"
        icon_path = File.join(root, "packages/ruflet_core/lib/ruflet_ui/ruflet/icons/cupertino/cupertino_icons.json")
        icon_map = JSON.parse(File.read(icon_path)).transform_keys { |key| key.to_s.upcase }
        output.write("module Ruflet; module CupertinoIconLookup; COMPILED_ICON_MAP = #{icon_map.inspect}.freeze; end; end\n")
      end
      output.write("\n# feature: #{feature}\n")
      output.write(File.binread(features.fetch(feature)))
      output.write("\n")
    end
    output.write("\n# Register every compiled gem feature with the VM require loader.\n")
    ordered.each do |feature|
      output.write("$LOADED_FEATURES << #{feature.inspect} unless $LOADED_FEATURES.include?(#{feature.inspect})\n")
      virtual_path = "/__preloaded_gems__/#{feature}.rb"
      output.write("$LOADED_FEATURES << #{virtual_path.inspect} unless $LOADED_FEATURES.include?(#{virtual_path.inspect})\n")
    end
  end
  spec.rbfiles = [File.join(__dir__, "mrblib/00_prelude.rb"), thread_compat, combined]
end
