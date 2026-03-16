# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class AppBarControl < Ruflet::Control
          TYPE = "appbar".freeze
          WIRE = "AppBar".freeze

          def initialize(id: nil, actions: nil, actions_padding: nil, adaptive: nil, automatically_imply_leading: nil, badge: nil, bgcolor: nil, center_title: nil, clip_behavior: nil, col: nil, color: nil, data: nil, disabled: nil, elevation: nil, elevation_on_scroll: nil, exclude_header_semantics: nil, expand: nil, expand_loose: nil, force_material_transparency: nil, key: nil, leading: nil, leading_width: nil, opacity: nil, rtl: nil, secondary: nil, shadow_color: nil, shape: nil, title: nil, title_spacing: nil, title_text_style: nil, toolbar_height: nil, toolbar_opacity: nil, toolbar_text_style: nil, tooltip: nil, visible: nil)
            props = {}
            props[:actions] = actions unless actions.nil?
            props[:actions_padding] = actions_padding unless actions_padding.nil?
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:automatically_imply_leading] = automatically_imply_leading unless automatically_imply_leading.nil?
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:center_title] = center_title unless center_title.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:color] = color unless color.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:elevation_on_scroll] = elevation_on_scroll unless elevation_on_scroll.nil?
            props[:exclude_header_semantics] = exclude_header_semantics unless exclude_header_semantics.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:force_material_transparency] = force_material_transparency unless force_material_transparency.nil?
            props[:key] = key unless key.nil?
            props[:leading] = leading unless leading.nil?
            props[:leading_width] = leading_width unless leading_width.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:secondary] = secondary unless secondary.nil?
            props[:shadow_color] = shadow_color unless shadow_color.nil?
            props[:shape] = shape unless shape.nil?
            props[:title] = title unless title.nil?
            props[:title_spacing] = title_spacing unless title_spacing.nil?
            props[:title_text_style] = title_text_style unless title_text_style.nil?
            props[:toolbar_height] = toolbar_height unless toolbar_height.nil?
            props[:toolbar_opacity] = toolbar_opacity unless toolbar_opacity.nil?
            props[:toolbar_text_style] = toolbar_text_style unless toolbar_text_style.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
