# frozen_string_literal: true

require_relative "../../icon_data"
require_relative "../material_icon_lookup"

module Ruflet
  module MaterialIcons
    module_function

    ICONS = begin
      source = Ruflet::MaterialIconLookup.icon_map
      if source.empty?
        {
          HOME: "home",
          SETTINGS: "settings",
          SEARCH: "search",
          ADD: "add",
          CLOSE: "close"
        }
      else
        source.keys.each_with_object({}) do |name, result|
          text = name.to_s.gsub(/[^a-zA-Z0-9]/, "_").gsub(/_+/, "_").sub(/\A_/, "").sub(/_\z/, "")
          text = "ICON_#{text}" if text.match?(/\A\d/)
          result[text.upcase.to_sym] = name
        end
      end.freeze
    end

    ICONS.each do |const_name, icon_name|
      next if const_defined?(const_name, false)

      const_set(const_name, icon_name.to_s.downcase)
    end

    def [](name)
      key = name.to_s.upcase.to_sym
      return const_get(key) if const_defined?(key, false)

      Ruflet::MaterialIconLookup.canonical_name_for(name) || name.to_s
    end

    def constants(_inherit = true)
      ICONS.keys
    end

    def all
      ICONS.keys.map { |k| const_get(k) }
    end

    def random
      all.sample || "help_outline"
    end

    def names
      ICONS.values
    end

  end
end
