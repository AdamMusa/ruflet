# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ListTileControl < Ruflet::Control
          TYPE = "listtile".freeze
          WIRE = "ListTile".freeze

          def initialize(id: nil, adaptive: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, autofocus: nil, badge: nil, bgcolor: nil, bottom: nil, col: nil, content_padding: nil, data: nil, dense: nil, disabled: nil, enable_feedback: nil, expand: nil, expand_loose: nil, height: nil, horizontal_spacing: nil, hover_color: nil, icon_color: nil, is_three_line: nil, key: nil, leading: nil, leading_and_trailing_text_style: nil, left: nil, margin: nil, min_height: nil, min_leading_width: nil, min_vertical_padding: nil, mouse_cursor: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, scale: nil, selected: nil, selected_color: nil, selected_tile_color: nil, shape: nil, size_change_interval: nil, splash_color: nil, style: nil, subtitle: nil, subtitle_text_style: nil, text_color: nil, title: nil, title_alignment: nil, title_text_style: nil, toggle_inputs: nil, tooltip: nil, top: nil, trailing: nil, url: nil, visible: nil, visual_density: nil, width: nil, on_animation_end: nil, on_click: nil, on_long_press: nil, on_size_change: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:align] = align unless align.nil?
            props[:animate_align] = animate_align unless animate_align.nil?
            props[:animate_margin] = animate_margin unless animate_margin.nil?
            props[:animate_offset] = animate_offset unless animate_offset.nil?
            props[:animate_opacity] = animate_opacity unless animate_opacity.nil?
            props[:animate_position] = animate_position unless animate_position.nil?
            props[:animate_rotation] = animate_rotation unless animate_rotation.nil?
            props[:animate_scale] = animate_scale unless animate_scale.nil?
            props[:animate_size] = animate_size unless animate_size.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:autofocus] = autofocus unless autofocus.nil?
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:content_padding] = content_padding unless content_padding.nil?
            props[:data] = data unless data.nil?
            props[:dense] = dense unless dense.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:enable_feedback] = enable_feedback unless enable_feedback.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:horizontal_spacing] = horizontal_spacing unless horizontal_spacing.nil?
            props[:hover_color] = hover_color unless hover_color.nil?
            props[:icon_color] = icon_color unless icon_color.nil?
            props[:is_three_line] = is_three_line unless is_three_line.nil?
            props[:key] = key unless key.nil?
            props[:leading] = leading unless leading.nil?
            props[:leading_and_trailing_text_style] = leading_and_trailing_text_style unless leading_and_trailing_text_style.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:min_height] = min_height unless min_height.nil?
            props[:min_leading_width] = min_leading_width unless min_leading_width.nil?
            props[:min_vertical_padding] = min_vertical_padding unless min_vertical_padding.nil?
            props[:mouse_cursor] = mouse_cursor unless mouse_cursor.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:selected] = selected unless selected.nil?
            props[:selected_color] = selected_color unless selected_color.nil?
            props[:selected_tile_color] = selected_tile_color unless selected_tile_color.nil?
            props[:shape] = shape unless shape.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:splash_color] = splash_color unless splash_color.nil?
            props[:style] = style unless style.nil?
            props[:subtitle] = subtitle unless subtitle.nil?
            props[:subtitle_text_style] = subtitle_text_style unless subtitle_text_style.nil?
            props[:text_color] = text_color unless text_color.nil?
            props[:title] = title unless title.nil?
            props[:title_alignment] = title_alignment unless title_alignment.nil?
            props[:title_text_style] = title_text_style unless title_text_style.nil?
            props[:toggle_inputs] = toggle_inputs unless toggle_inputs.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:trailing] = trailing unless trailing.nil?
            props[:url] = url unless url.nil?
            props[:visible] = visible unless visible.nil?
            props[:visual_density] = visual_density unless visual_density.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_click] = on_click unless on_click.nil?
            props[:on_long_press] = on_long_press unless on_long_press.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
