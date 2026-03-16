# frozen_string_literal: true

module Ruflet
  module UI
    module Types
      module TextOverflow
        CLIP = "clip"
        ELLIPSIS = "ellipsis"
        FADE = "fade"
        VISIBLE = "visible"
      end

      module TextBaseline
        ALPHABETIC = "alphabetic"
        IDEOGRAPHIC = "ideographic"
      end

      module TextThemeStyle
        DISPLAY_LARGE = "displayLarge"
        DISPLAY_MEDIUM = "displayMedium"
        DISPLAY_SMALL = "displaySmall"
        HEADLINE_LARGE = "headlineLarge"
        HEADLINE_MEDIUM = "headlineMedium"
        HEADLINE_SMALL = "headlineSmall"
        TITLE_LARGE = "titleLarge"
        TITLE_MEDIUM = "titleMedium"
        TITLE_SMALL = "titleSmall"
        LABEL_LARGE = "labelLarge"
        LABEL_MEDIUM = "labelMedium"
        LABEL_SMALL = "labelSmall"
        BODY_LARGE = "bodyLarge"
        BODY_MEDIUM = "bodyMedium"
        BODY_SMALL = "bodySmall"
      end

      module TextDecoration
        NONE = 0
        UNDERLINE = 1
        OVERLINE = 2
        LINE_THROUGH = 4

        module_function

        def combine(decorations)
          Array(decorations).compact.reduce(NONE) { |acc, item| acc | item.to_i }
        end
      end

      module TextDecorationStyle
        SOLID = "solid"
        DOUBLE = "double"
        DOTTED = "dotted"
        DASHED = "dashed"
        WAVY = "wavy"
      end

      class TextStyle
        ATTRS = %i[
          size
          height
          weight
          italic
          decoration
          decoration_color
          decoration_thickness
          decoration_style
          font_family
          font_family_fallback
          color
          bgcolor
          shadow
          foreground
          letter_spacing
          word_spacing
          overflow
          baseline
        ].freeze

        attr_reader(*ATTRS)

        def initialize(
          size: nil,
          height: nil,
          weight: nil,
          italic: false,
          decoration: nil,
          decoration_color: nil,
          decoration_thickness: nil,
          decoration_style: nil,
          font_family: nil,
          font_family_fallback: nil,
          color: nil,
          bgcolor: nil,
          shadow: nil,
          foreground: nil,
          letter_spacing: nil,
          word_spacing: nil,
          overflow: nil,
          baseline: nil
        )
          @size = size
          @height = height
          @weight = weight
          @italic = italic
          @decoration = decoration
          @decoration_color = decoration_color
          @decoration_thickness = decoration_thickness
          @decoration_style = decoration_style
          @font_family = font_family
          @font_family_fallback = font_family_fallback
          @color = color
          @bgcolor = bgcolor
          @shadow = shadow
          @foreground = foreground
          @letter_spacing = letter_spacing
          @word_spacing = word_spacing
          @overflow = overflow
          @baseline = baseline
        end

        def copy(**overrides)
          self.class.new(**ATTRS.each_with_object({}) do |attr, out|
            out[attr] = overrides.key?(attr) ? overrides[attr] : public_send(attr)
          end)
        end

        def to_h
          hash = {}
          ATTRS.each do |attr|
            value = public_send(attr)
            next if value.nil?
            next if attr == :italic && value == false

            hash[attr.to_s] = value
          end
          hash
        end
      end

      class StrutStyle
        ATTRS = %i[
          size
          height
          weight
          italic
          font_family
          leading
          force_strut_height
        ].freeze

        attr_reader(*ATTRS)

        def initialize(
          size: nil,
          height: nil,
          weight: nil,
          italic: false,
          font_family: nil,
          leading: nil,
          force_strut_height: nil
        )
          @size = size
          @height = height
          @weight = weight
          @italic = italic
          @font_family = font_family
          @leading = leading
          @force_strut_height = force_strut_height
        end

        def copy(**overrides)
          self.class.new(**ATTRS.each_with_object({}) do |attr, out|
            out[attr] = overrides.key?(attr) ? overrides[attr] : public_send(attr)
          end)
        end

        def to_h
          hash = {}
          ATTRS.each do |attr|
            value = public_send(attr)
            next if value.nil?
            next if attr == :italic && value == false

            hash[attr.to_s] = value
          end
          hash
        end
      end
    end
  end
end
