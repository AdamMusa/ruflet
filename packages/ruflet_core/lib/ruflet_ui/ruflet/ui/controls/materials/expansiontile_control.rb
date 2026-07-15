# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ExpansionTileControl < Ruflet::Control
          TYPE = "expansiontile".freeze
          WIRE = "ExpansionTile".freeze

          KEYWORDS = [:adaptive, :affinity, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :animation_style, :aspect_ratio, :badge, :bgcolor, :bottom, :clip_behavior, :col, :collapsed_bgcolor, :collapsed_icon_color, :collapsed_shape, :collapsed_text_color, :controls, :controls_padding, :data, :dense, :disabled, :enable_feedback, :expand, :expand_loose, :expanded, :expanded_alignment, :expanded_cross_axis_alignment, :height, :icon_color, :key, :leading, :left, :maintain_state, :margin, :min_tile_height, :offset, :opacity, :right, :rotate, :rtl, :scale, :shape, :show_trailing_icon, :size_change_interval, :subtitle, :text_color, :tile_padding, :title, :tooltip, :top, :trailing, :visible, :visual_density, :width, :on_animation_end, :on_change, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            adaptive = props[:adaptive]
            affinity = props[:affinity]
            align = props[:align]
            animate_align = props[:animate_align]
            animate_margin = props[:animate_margin]
            animate_offset = props[:animate_offset]
            animate_opacity = props[:animate_opacity]
            animate_position = props[:animate_position]
            animate_rotation = props[:animate_rotation]
            animate_scale = props[:animate_scale]
            animate_size = props[:animate_size]
            animation_style = props[:animation_style]
            aspect_ratio = props[:aspect_ratio]
            badge = props[:badge]
            bgcolor = props[:bgcolor]
            bottom = props[:bottom]
            clip_behavior = props[:clip_behavior]
            col = props[:col]
            collapsed_bgcolor = props[:collapsed_bgcolor]
            collapsed_icon_color = props[:collapsed_icon_color]
            collapsed_shape = props[:collapsed_shape]
            collapsed_text_color = props[:collapsed_text_color]
            controls = props[:controls]
            controls_padding = props[:controls_padding]
            data = props[:data]
            dense = props[:dense]
            disabled = props[:disabled]
            enable_feedback = props[:enable_feedback]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            expanded = props[:expanded]
            expanded_alignment = props[:expanded_alignment]
            expanded_cross_axis_alignment = props[:expanded_cross_axis_alignment]
            height = props[:height]
            icon_color = props[:icon_color]
            key = props[:key]
            leading = props[:leading]
            left = props[:left]
            maintain_state = props[:maintain_state]
            margin = props[:margin]
            min_tile_height = props[:min_tile_height]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            shape = props[:shape]
            show_trailing_icon = props[:show_trailing_icon]
            size_change_interval = props[:size_change_interval]
            subtitle = props[:subtitle]
            text_color = props[:text_color]
            tile_padding = props[:tile_padding]
            title = props[:title]
            tooltip = props[:tooltip]
            top = props[:top]
            trailing = props[:trailing]
            visible = props[:visible]
            visual_density = props[:visual_density]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_change = props[:on_change]
            on_size_change = props[:on_size_change]
            raise ArgumentError, "expansion_tile requires title" if title.nil?
            expanded = false if expanded.nil?
            maintain_state = false if maintain_state.nil?
            show_trailing_icon = true if show_trailing_icon.nil?

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
