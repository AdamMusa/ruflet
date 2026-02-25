# frozen_string_literal: true

require_relative "../../icon_data"
require_relative "../cupertino_icon_lookup"

module Ruflet
  module CupertinoIcons
    module_function

    ICONS = begin
      source = Ruflet::CupertinoIconLookup.icon_map
      if source.empty?
        {
          HOME: "house",
          SEARCH: "search",
          SETTINGS: "gear",
          ADD: "add",
          CLOSE: "clear"
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

      const_set(const_name, Ruflet::IconData.new(icon_name))
    end

    def [](name)
      key = name.to_s.upcase.to_sym
      return const_get(key) if const_defined?(key, false)

      Ruflet::IconData.new(name.to_s)
    end

    def all
      ICONS.keys.map { |k| const_get(k) }
    end

    def random
      all.sample || Ruflet::IconData.new(Ruflet::CupertinoIconLookup.fallback_codepoint)
    end

    def names
      ICONS.values
    end
  end
end
