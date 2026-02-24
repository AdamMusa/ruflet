# frozen_string_literal: true

module RubyNative
  module CupertinoIconLookup
    module_function

    def codepoint_for(value)
      if value.is_a?(Integer)
        return value if value >= (2 << 16)
        translated = legacy_codepoint_map[value]
        return translated unless translated.nil?
        return value
      end

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
      icons["QUESTION_CIRCLE"] || icons["QUESTION"] || 0
    end

    def icon_map
      @icon_map ||= load_icon_map
    end

    def legacy_codepoint_map
      @legacy_codepoint_map ||= build_legacy_codepoint_map
    end

    def candidate_names(name)
      raw = name.to_s.strip
      return [] if raw.empty?

      underscored = raw.gsub(/\s+|-/, "_").downcase
      stripped = underscored.sub(/\Acupertinoicons\./i, "")
      upper = stripped.upcase

      [raw, raw.upcase, underscored, stripped, upper].uniq
    end

    def parse_numeric(text)
      return text.to_i(16) if text.match?(/\A0x[0-9a-fA-F]+\z/)
      return text.to_i if text.match?(/\A\d+\z/)

      nil
    end

    def load_icon_map
      path = flet_cupertino_icons_json_file
      if path && File.file?(path)
        return parse_icons_json(path)
      end

      dart_list = flet_cupertino_icons_dart_file
      if dart_list && File.file?(dart_list)
        return parse_flet_icons_dart(dart_list, icon_prefix: "CupertinoIcons.", set_id: 2)
      end

      {}
    end

    def flet_cupertino_icons_json_file
      candidate_from_flet_checkout("sdk/python/packages/flet/src/flet/controls/cupertino/cupertino_icons.json")
    end

    def flet_cupertino_icons_dart_file
      candidate_from_flet_checkout("packages/flet/lib/src/utils/cupertino_icons.dart")
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

    def flutter_icons_file
      root = ENV["FLUTTER_ROOT"]
      if root && !root.empty?
        candidate = File.join(root, "packages", "flutter", "lib", "src", "cupertino", "icons.dart")
        return candidate if File.file?(candidate)
      end

      flutter_bin = `which flutter 2>/dev/null`.strip
      return nil if flutter_bin.empty?

      sdk_root = File.expand_path("..", File.dirname(flutter_bin))
      candidate = File.join(sdk_root, "packages", "flutter", "lib", "src", "cupertino", "icons.dart")
      File.file?(candidate) ? candidate : nil
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

    def parse_flutter_icons_file(path)
      mapping = {}
      pending_name = nil

      File.foreach(path) do |line|
        if (match = line.match(/^\s*static const IconData (\w+) = IconData\((0x[0-9a-fA-F]+|\d+)/))
          mapping[match[1].upcase] = Integer(match[2])
          pending_name = nil
          next
        end

        if (match = line.match(/^\s*static const IconData (\w+) = IconData\(\s*$/))
          pending_name = match[1]
          next
        end

        next unless pending_name

        if (match = line.match(/^\s*(0x[0-9a-fA-F]+|\d+),/))
          mapping[pending_name.upcase] = Integer(match[1])
          pending_name = nil
        elsif line.include?(");")
          pending_name = nil
        end
      end

      mapping
    end

    def build_legacy_codepoint_map
      flutter_path = flutter_icons_file
      return {} unless flutter_path && File.file?(flutter_path)

      flutter_map = parse_flutter_icons_file(flutter_path) # NAME => codepoint
      encoded_map = icon_map # NAME => encoded

      flutter_map.each_with_object({}) do |(name, codepoint), out|
        encoded = encoded_map[name]
        out[codepoint] = encoded unless encoded.nil?
      end
    end
  end
end
