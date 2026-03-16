# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ExpansionTileControl < Ruflet::Control
          TYPE = "expansiontile".freeze
          WIRE = "ExpansionTile".freeze

          def initialize(id: nil, adaptive: nil, affinity: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, animation_style: nil, aspect_ratio: nil, badge: nil, bgcolor: nil, bottom: nil, clip_behavior: nil, col: nil, collapsed_bgcolor: nil, collapsed_icon_color: nil, collapsed_shape: nil, collapsed_text_color: nil, controls: nil, controls_padding: nil, data: nil, dense: nil, disabled: nil, enable_feedback: nil, expand: nil, expand_loose: nil, expanded: nil, expanded_alignment: nil, expanded_cross_axis_alignment: nil, height: nil, icon_color: nil, key: nil, leading: nil, left: nil, maintain_state: nil, margin: nil, min_tile_height: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, scale: nil, shape: nil, show_trailing_icon: nil, size_change_interval: nil, subtitle: nil, text_color: nil, tile_padding: nil, title: nil, tooltip: nil, top: nil, trailing: nil, visible: nil, visual_density: nil, width: nil, on_animation_end: nil, on_change: nil, on_size_change: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:affinity] = affinity unless affinity.nil?
            props[:align] = align unless align.nil?
            props[:animate_align] = animate_align unless animate_align.nil?
            props[:animate_margin] = animate_margin unless animate_margin.nil?
            props[:animate_offset] = animate_offset unless animate_offset.nil?
            props[:animate_opacity] = animate_opacity unless animate_opacity.nil?
            props[:animate_position] = animate_position unless animate_position.nil?
            props[:animate_rotation] = animate_rotation unless animate_rotation.nil?
            props[:animate_scale] = animate_scale unless animate_scale.nil?
            props[:animate_size] = animate_size unless animate_size.nil?
            props[:animation_style] = animation_style unless animation_style.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:collapsed_bgcolor] = collapsed_bgcolor unless collapsed_bgcolor.nil?
            props[:collapsed_icon_color] = collapsed_icon_color unless collapsed_icon_color.nil?
            props[:collapsed_shape] = collapsed_shape unless collapsed_shape.nil?
            props[:collapsed_text_color] = collapsed_text_color unless collapsed_text_color.nil?
            props[:controls] = controls unless controls.nil?
            props[:controls_padding] = controls_padding unless controls_padding.nil?
            props[:data] = data unless data.nil?
            props[:dense] = dense unless dense.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:enable_feedback] = enable_feedback unless enable_feedback.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:expanded] = expanded unless expanded.nil?
            props[:expanded_alignment] = expanded_alignment unless expanded_alignment.nil?
            props[:expanded_cross_axis_alignment] = expanded_cross_axis_alignment unless expanded_cross_axis_alignment.nil?
            props[:height] = height unless height.nil?
            props[:icon_color] = icon_color unless icon_color.nil?
            props[:key] = key unless key.nil?
            props[:leading] = leading unless leading.nil?
            props[:left] = left unless left.nil?
            props[:maintain_state] = maintain_state unless maintain_state.nil?
            props[:margin] = margin unless margin.nil?
            props[:min_tile_height] = min_tile_height unless min_tile_height.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:shape] = shape unless shape.nil?
            props[:show_trailing_icon] = show_trailing_icon unless show_trailing_icon.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:subtitle] = subtitle unless subtitle.nil?
            props[:text_color] = text_color unless text_color.nil?
            props[:tile_padding] = tile_padding unless tile_padding.nil?
            props[:title] = title unless title.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:trailing] = trailing unless trailing.nil?
            props[:visible] = visible unless visible.nil?
            props[:visual_density] = visual_density unless visual_density.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
