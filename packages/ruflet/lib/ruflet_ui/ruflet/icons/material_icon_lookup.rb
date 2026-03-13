# frozen_string_literal: true

require "json"

module Ruflet
  module MaterialIconLookup
    module_function

    LOCAL_ICONS_JSON = File.expand_path("material/icons.json", __dir__)

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
      return {} unless File.file?(LOCAL_ICONS_JSON)

      parse_icons_json(LOCAL_ICONS_JSON)
    end

    def parse_icons_json(path)
      parsed = JSON.parse(File.read(path))
      parsed.each_with_object({}) do |(k, v), out|
        out[k.to_s.upcase] = v.to_i
      end
    end

  end
end
