# frozen_string_literal: true

module RubyNative
  module Colors
    module_function

    SEMANTIC_COLORS = {
      PRIMARY: "primary",
      ON_PRIMARY: "onprimary",
      PRIMARY_CONTAINER: "primarycontainer",
      ON_PRIMARY_CONTAINER: "onprimarycontainer",
      PRIMARY_FIXED: "primaryfixed",
      PRIMARY_FIXED_DIM: "primaryfixeddim",
      ON_PRIMARY_FIXED: "onprimaryfixed",
      ON_PRIMARY_FIXED_VARIANT: "onprimaryfixedvariant",
      SECONDARY: "secondary",
      ON_SECONDARY: "onsecondary",
      SECONDARY_CONTAINER: "secondarycontainer",
      ON_SECONDARY_CONTAINER: "onsecondarycontainer",
      SECONDARY_FIXED: "secondaryfixed",
      SECONDARY_FIXED_DIM: "secondaryfixeddim",
      ON_SECONDARY_FIXED: "onsecondaryfixed",
      ON_SECONDARY_FIXED_VARIANT: "onsecondaryfixedvariant",
      TERTIARY: "tertiary",
      ON_TERTIARY: "ontertiary",
      TERTIARY_CONTAINER: "tertiarycontainer",
      ON_TERTIARY_CONTAINER: "ontertiarycontainer",
      TERTIARY_FIXED: "tertiaryfixed",
      TERTIARY_FIXED_DIM: "tertiaryfixeddim",
      ON_TERTIARY_FIXED: "ontertiaryfixed",
      ON_TERTIARY_FIXED_VARIANT: "ontertiaryfixedvariant",
      ERROR: "error",
      ON_ERROR: "onerror",
      ERROR_CONTAINER: "errorcontainer",
      ON_ERROR_CONTAINER: "onerrorcontainer",
      SURFACE: "surface",
      ON_SURFACE: "onsurface",
      ON_SURFACE_VARIANT: "onsurfacevariant",
      SURFACE_TINT: "surfacetint",
      SURFACE_DIM: "surfacedim",
      SURFACE_BRIGHT: "surfacebright",
      SURFACE_CONTAINER: "surfacecontainer",
      SURFACE_CONTAINER_LOW: "surfacecontainerlow",
      SURFACE_CONTAINER_LOWEST: "surfacecontainerlowest",
      SURFACE_CONTAINER_HIGH: "surfacecontainerhigh",
      SURFACE_CONTAINER_HIGHEST: "surfacecontainerhighest",
      OUTLINE: "outline",
      OUTLINE_VARIANT: "outlinevariant",
      SHADOW: "shadow",
      SCRIM: "scrim",
      INVERSE_SURFACE: "inversesurface",
      ON_INVERSE_SURFACE: "oninversesurface",
      INVERSE_PRIMARY: "inverseprimary"
    }.freeze

    BASE_PRIMARY = %w[
      amber blue bluegrey brown cyan deeporange deeppurple green grey indigo lightblue
      lightgreen lime orange pink purple red teal yellow
    ].freeze
    BASE_ACCENT = %w[
      amber blue cyan deeporange deeppurple green indigo lightblue lightgreen lime
      orange pink purple red teal yellow
    ].freeze
    PRIMARY_SHADES = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900].freeze
    ACCENT_SHADES = [100, 200, 400, 700].freeze

    FIXED_COLORS = {
      BLACK: "black",
      BLACK_12: "black12",
      BLACK_26: "black26",
      BLACK_38: "black38",
      BLACK_45: "black45",
      BLACK_54: "black54",
      BLACK_87: "black87",
      WHITE: "white",
      WHITE_10: "white10",
      WHITE_12: "white12",
      WHITE_24: "white24",
      WHITE_30: "white30",
      WHITE_38: "white38",
      WHITE_54: "white54",
      WHITE_60: "white60",
      WHITE_70: "white70",
      TRANSPARENT: "transparent"
    }.freeze

    DEPRECATED_ALIASES = {
      BLACK12: :BLACK_12,
      BLACK26: :BLACK_26,
      BLACK38: :BLACK_38,
      BLACK45: :BLACK_45,
      BLACK54: :BLACK_54,
      BLACK87: :BLACK_87,
      WHITE10: :WHITE_10,
      WHITE12: :WHITE_12,
      WHITE24: :WHITE_24,
      WHITE30: :WHITE_30,
      WHITE38: :WHITE_38,
      WHITE54: :WHITE_54,
      WHITE60: :WHITE_60,
      WHITE70: :WHITE_70
    }.freeze

    def with_opacity(opacity, color)
      value = Float(opacity)
      raise ArgumentError, "opacity must be between 0.0 and 1.0 inclusive, got #{opacity}" unless value.between?(0.0, 1.0)

      "#{normalize_color(color)},#{value}"
    end

    def random(exclude: nil, weights: nil)
      choices = all_values.dup
      excluded = Array(exclude).map { |c| normalize_color(c) }
      choices.reject! { |c| excluded.include?(c) }
      return nil if choices.empty?

      if weights && !weights.empty?
        expanded = choices.flat_map do |color|
          weight = weights.fetch(color, weights.fetch(color.to_sym, 1)).to_i rescue 1
          weight = 1 if weight <= 0
          [color] * weight
        end
        return expanded.sample
      end

      choices.sample
    end

    def all_values
      @all_values ||= constants(false)
                      .map { |c| const_get(c) }
                      .select { |v| v.is_a?(String) }
                      .uniq
                      .freeze
    end

    def normalize_color(color)
      return color.to_s if color.is_a?(Symbol)
      return color if color.is_a?(String)
      return color.to_s unless color.respond_to?(:to_s)

      color.to_s
    end

    BASE_PREFIX = {
      "amber" => "AMBER",
      "blue" => "BLUE",
      "bluegrey" => "BLUE_GREY",
      "brown" => "BROWN",
      "cyan" => "CYAN",
      "deeporange" => "DEEP_ORANGE",
      "deeppurple" => "DEEP_PURPLE",
      "green" => "GREEN",
      "grey" => "GREY",
      "indigo" => "INDIGO",
      "lightblue" => "LIGHT_BLUE",
      "lightgreen" => "LIGHT_GREEN",
      "lime" => "LIME",
      "orange" => "ORANGE",
      "pink" => "PINK",
      "purple" => "PURPLE",
      "red" => "RED",
      "teal" => "TEAL",
      "yellow" => "YELLOW"
    }.freeze

    def constant_prefix_for(base_name)
      BASE_PREFIX.fetch(base_name) { base_name.upcase }
    end

    SEMANTIC_COLORS.each { |k, v| const_set(k, v) }
    FIXED_COLORS.each { |k, v| const_set(k, v) }

    BASE_PRIMARY.each do |base|
      prefix = constant_prefix_for(base)
      const_set(prefix, base)
      PRIMARY_SHADES.each do |shade|
        const_set("#{prefix}_#{shade}", "#{base}#{shade}")
      end
    end

    BASE_ACCENT.each do |base|
      prefix = "#{constant_prefix_for(base)}_ACCENT"
      const_set(prefix, "#{base}accent")
      ACCENT_SHADES.each do |shade|
        const_set("#{prefix}_#{shade}", "#{base}accent#{shade}")
      end
    end

    DEPRECATED_ALIASES.each do |alias_name, target|
      const_set(alias_name, const_get(target))
    end

    constants(false).each do |name|
      next if respond_to?(name)

      define_singleton_method(name) { const_get(name) }
    end
  end
end
