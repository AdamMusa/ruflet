# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class AppBarControl < Ruflet::Control
          TYPE = "appbar".freeze
          WIRE = "AppBar".freeze

          KEYWORDS = [:actions, :actions_padding, :adaptive, :automatically_imply_leading, :badge, :bgcolor, :center_title, :clip_behavior, :col, :color, :data, :disabled, :elevation, :elevation_on_scroll, :exclude_header_semantics, :expand, :expand_loose, :force_material_transparency, :key, :leading, :leading_width, :opacity, :rtl, :secondary, :shadow_color, :shape, :title, :title_spacing, :title_text_style, :toolbar_height, :toolbar_opacity, :toolbar_text_style, :tooltip, :visible].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end
        end
      end
    end
  end
end
