# frozen_string_literal: true

require_relative "../../icon_data"
require_relative "../icon_constant_names"
require_relative "../material_icon_lookup"

module Ruflet
  # Material icon names, exposed as constants: Ruflet::MaterialIcons::HOME.
  #
  # The constants are materialized on demand rather than at load. Building all
  # of them eagerly meant interning ~8,800 symbols, filling a hash with them and
  # calling const_set ~8,800 times every time the VM opened -- on the embedded
  # mruby runtime that was the single largest item in application cold start,
  # and an app typically names a handful of icons. const_missing keeps the
  # constant syntax working, so nothing at the call site changes.
  module MaterialIcons
    module_function

    FALLBACK_ICONS = {
      HOME: "home",
      SETTINGS: "settings",
      SEARCH: "search",
      ADD: "add",
      CLOSE: "close"
    }.freeze

    # Constant name -> icon name, e.g. :ACCESS_ALARM => "ACCESS_ALARM". Built on
    # first use by anything that needs the whole table; single constant lookups
    # do not need it at all (see const_missing).
    def icons
      @icons ||= begin
        source = Ruflet::MaterialIconLookup.icon_map
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

    def [](name)
      icon = icons[name.to_s.upcase.to_sym]
      return icon.to_s.downcase unless icon.nil?

      Ruflet::MaterialIconLookup.canonical_name_for(name) || name.to_s
    end

    def constants(_inherit = true)
      icons.keys
    end

    def all
      icons.values.map { |name| name.to_s.downcase }
    end

    def random
      all.sample || "help_outline"
    end

    def names
      icons.values
    end

    class << self
      # Materializes one icon constant, or returns nil when the name is not an
      # icon. Callers that used to probe with const_defined?(name, false) must
      # come through here instead: with deferred constants, const_defined? is
      # false for every icon nobody has referenced yet.
      def resolve_constant(name)
        return const_get(name) if const_defined?(name, false)

        # ICONS stayed a public constant for callers that want the whole table.
        return const_set(:ICONS, icons) if name == :ICONS

        # Most constant names are already a key of the compiled map, so the
        # common case is one hash hit and never builds the reverse table.
        key = name.to_s
        source = Ruflet::MaterialIconLookup.icon_map
        return const_set(name, key.downcase) if source.key?(key)

        icon = icons[name]
        icon.nil? ? nil : const_set(name, icon.to_s.downcase)
      end

      def const_missing(name)
        resolved = resolve_constant(name)
        resolved.nil? ? super : resolved
      end
    end
  end
end
