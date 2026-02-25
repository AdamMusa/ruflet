# frozen_string_literal: true

module Ruflet
  module MaterialIconLookup
    module_function

    def codepoint_for(value)
      return value if value.is_a?(Integer)

      text = value.to_s.strip
      return nil if text.empty?

      numeric = parse_numeric(text)
      return numeric unless numeric.nil?

      icons = icon_map
      candidate_names(text).each do |name|
        codepoint = icons[name]
        return codepoint unless codepoint.nil?
      end

      nil
    end

    def fallback_codepoint
      icons = icon_map
      icons["HELP_OUTLINE"] || icons["HELP"] || icons["QUESTION_MARK"] || 0
    end

    def icon_map
      @icon_map ||= load_icon_map
    end

    def candidate_names(name)
      raw = name.to_s.strip
      return [] if raw.empty?

      underscored = raw.gsub(/\s+|-/, "_").downcase
      stripped = underscored.sub(/\Aicons\./, "")
      upper = stripped.upcase

      [raw, raw.upcase, underscored, stripped, upper].uniq
    end

    def parse_numeric(text)
      return text.to_i(16) if text.match?(/\A0x[0-9a-fA-F]+\z/)
      return text.to_i if text.match?(/\A\d+\z/)

      nil
    end

    def load_icon_map
      path = flet_material_icons_json_file
      if path && File.file?(path)
        return parse_icons_json(path)
      end

      dart_list = flet_material_icons_dart_file
      if dart_list && File.file?(dart_list)
        return parse_flet_icons_dart(dart_list, icon_prefix: "Icons.", set_id: 1)
      end

      {}
    end

    def flet_material_icons_json_file
      candidate_from_flet_checkout("sdk/python/packages/flet/src/flet/controls/material/icons.json")
    end

    def flet_material_icons_dart_file
      candidate_from_flet_checkout("packages/flet/lib/src/utils/material_icons.dart")
    end

    def candidate_from_flet_checkout(relative_path)
      flet_root = File.join(Dir.home, ".pub-cache", "git")
      return nil unless Dir.exist?(flet_root)

      entries = Dir.children(flet_root).select { |e| e.start_with?("flet-") }
      return nil if entries.empty?

      candidates = entries.map { |e| File.join(flet_root, e, relative_path) }.select { |p| File.file?(p) }
      return nil if candidates.empty?

      candidates.max_by { |p| File.mtime(p) rescue Time.at(0) }
    end

    def parse_icons_json(path)
      require "json"
      parsed = JSON.parse(File.read(path))
      parsed.each_with_object({}) do |(k, v), out|
        out[k.to_s.upcase] = v.to_i
      end
    end

    def parse_flet_icons_dart(path, icon_prefix:, set_id:)
      mapping = {}
      index = 0
      pattern = /^\s*#{Regexp.escape(icon_prefix)}([a-zA-Z0-9_]+),/

      File.foreach(path) do |line|
        next unless (match = line.match(pattern))

        encoded = (set_id << 16) | index
        mapping[match[1].upcase] = encoded
        index += 1
      end

      mapping
    end

  end
end
