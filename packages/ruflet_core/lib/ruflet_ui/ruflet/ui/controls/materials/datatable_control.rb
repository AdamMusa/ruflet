# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DataTableControl < Ruflet::Control
          TYPE = "datatable".freeze
          WIRE = "DataTable".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bgcolor: nil, border: nil, border_radius: nil, bottom: nil, checkbox_horizontal_margin: nil, clip_behavior: nil, col: nil, column_spacing: nil, columns: nil, data: nil, data_row_color: nil, data_row_max_height: nil, data_row_min_height: nil, data_text_style: nil, disabled: nil, divider_thickness: nil, expand: nil, expand_loose: nil, gradient: nil, heading_row_color: nil, heading_row_height: nil, heading_text_style: nil, height: nil, horizontal_lines: nil, horizontal_margin: nil, key: nil, left: nil, margin: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rows: nil, rtl: nil, scale: nil, show_bottom_border: nil, show_checkbox_column: nil, size_change_interval: nil, sort_ascending: nil, sort_column_index: nil, tooltip: nil, top: nil, vertical_lines: nil, visible: nil, width: nil, on_animation_end: nil, on_select_all: nil, on_size_change: nil)
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
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:border] = border unless border.nil?
            props[:border_radius] = border_radius unless border_radius.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:checkbox_horizontal_margin] = checkbox_horizontal_margin unless checkbox_horizontal_margin.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:column_spacing] = column_spacing unless column_spacing.nil?
            props[:columns] = columns unless columns.nil?
            props[:data] = data unless data.nil?
            props[:data_row_color] = data_row_color unless data_row_color.nil?
            props[:data_row_max_height] = data_row_max_height unless data_row_max_height.nil?
            props[:data_row_min_height] = data_row_min_height unless data_row_min_height.nil?
            props[:data_text_style] = data_text_style unless data_text_style.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:divider_thickness] = divider_thickness unless divider_thickness.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:gradient] = gradient unless gradient.nil?
            props[:heading_row_color] = heading_row_color unless heading_row_color.nil?
            props[:heading_row_height] = heading_row_height unless heading_row_height.nil?
            props[:heading_text_style] = heading_text_style unless heading_text_style.nil?
            props[:height] = height unless height.nil?
            props[:horizontal_lines] = horizontal_lines unless horizontal_lines.nil?
            props[:horizontal_margin] = horizontal_margin unless horizontal_margin.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rows] = rows unless rows.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:show_bottom_border] = show_bottom_border unless show_bottom_border.nil?
            props[:show_checkbox_column] = show_checkbox_column unless show_checkbox_column.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:sort_ascending] = sort_ascending unless sort_ascending.nil?
            props[:sort_column_index] = sort_column_index unless sort_column_index.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:vertical_lines] = vertical_lines unless vertical_lines.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_select_all] = on_select_all unless on_select_all.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
