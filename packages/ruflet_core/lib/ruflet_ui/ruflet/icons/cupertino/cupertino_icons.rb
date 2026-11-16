# frozen_string_literal: true

require_relative "../icon_constant_names"
require_relative "../cupertino_icon_lookup"

module Ruflet
  # Cupertino icon names, exposed as constants. Materialized on demand for the
  # same reason as Ruflet::MaterialIcons -- see the note there.
  module CupertinoIcons
    module_function

    FALLBACK_ICONS = {
      HOME: "house",
      SEARCH: "search",
      SETTINGS: "gear",
      ADD: "add",
      CLOSE: "clear"
    }.freeze

    def icons
      @icons ||= begin
        source = Ruflet::CupertinoIconLookup.icon_map
        if source.empty?
          FALLBACK_ICONS
        else
          source.keys.each_with_object({}) do |name, result|
            text = Ruflet::IconNames.constant_for(name)
            result[text.upcase.to_sym] = name
          end
        end.freeze
      end
    end

    # A name in this set, as a CupertinoIconName. See Ruflet::MaterialIcons.[].
    def [](name)
      found = Ruflet::CupertinoIconLookup.icon_name_for(name)
      return found unless found.nil?

      icon = icons[name.to_s.upcase.to_sym]
      icon.nil? ? name.to_s : Ruflet::CupertinoIconLookup.icon_name(icon)
    end

    def constants(_inherit = true)
      icons.keys
    end

    def all
      icons.values.map { |name| Ruflet::CupertinoIconLookup.icon_name(name) }
    end

    def random
      all.sample || Ruflet::CupertinoIconLookup.icon_name("question_circle")
    end

    def names
      icons.values
    end

    class << self
      # See Ruflet::MaterialIcons.resolve_constant.
      def resolve_constant(name, index: true)
        return const_get(name) if const_defined?(name, false)
        return const_set(:ICONS, icons) if name == :ICONS

        key = name.to_s
        source = Ruflet::CupertinoIconLookup.icon_map
        return const_set(name, Ruflet::CupertinoIconLookup.icon_name(key)) if source.key?(key)
        return nil unless index

        icon = icons[name]
        icon.nil? ? nil : const_set(name, Ruflet::CupertinoIconLookup.icon_name(icon))
      end

      def const_missing(name)
        resolved = resolve_constant(name)
        resolved.nil? ? super : resolved
      end
    end
  end
end
