# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class MarkdownControl < Ruflet::Control
          TYPE = "markdown".freeze
          WIRE = "Markdown".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, auto_follow_links: nil, auto_follow_links_target: nil, badge: nil, bottom: nil, code_style_sheet: nil, code_theme: nil, col: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, extension_set: nil, fit_content: nil, height: nil, image_error_content: nil, key: nil, latex_scale_factor: nil, latex_style: nil, left: nil, margin: nil, md_style_sheet: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, scale: nil, selectable: nil, shrink_wrap: nil, size_change_interval: nil, soft_line_break: nil, tooltip: nil, top: nil, value: nil, visible: nil, width: nil, on_animation_end: nil, on_selection_change: nil, on_size_change: nil, on_tap_link: nil, on_tap_text: nil)
            props = {}
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
            props[:auto_follow_links] = auto_follow_links unless auto_follow_links.nil?
            props[:auto_follow_links_target] = auto_follow_links_target unless auto_follow_links_target.nil?
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:code_style_sheet] = code_style_sheet unless code_style_sheet.nil?
            props[:code_theme] = code_theme unless code_theme.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:extension_set] = extension_set unless extension_set.nil?
            props[:fit_content] = fit_content unless fit_content.nil?
            props[:height] = height unless height.nil?
            props[:image_error_content] = image_error_content unless image_error_content.nil?
            props[:key] = key unless key.nil?
            props[:latex_scale_factor] = latex_scale_factor unless latex_scale_factor.nil?
            props[:latex_style] = latex_style unless latex_style.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:md_style_sheet] = md_style_sheet unless md_style_sheet.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:selectable] = selectable unless selectable.nil?
            props[:shrink_wrap] = shrink_wrap unless shrink_wrap.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:soft_line_break] = soft_line_break unless soft_line_break.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_selection_change] = on_selection_change unless on_selection_change.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            props[:on_tap_link] = on_tap_link unless on_tap_link.nil?
            props[:on_tap_text] = on_tap_text unless on_tap_text.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
