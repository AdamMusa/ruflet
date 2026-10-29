# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TableControl < Ruflet::Control
          TYPE = "table".freeze
          WIRE = "Table".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :border_color, :border_radius, :border_width, :bottom, :cell_padding, :col, :column_widths, :controls, :data, :default_column_width, :default_vertical_alignment, :disabled, :expand, :expand_loose, :height, :inner_borders, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rows, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            align = props[:align]
            animate_align = props[:animate_align]
            animate_margin = props[:animate_margin]
            animate_offset = props[:animate_offset]
            animate_opacity = props[:animate_opacity]
            animate_position = props[:animate_position]
            animate_rotation = props[:animate_rotation]
            animate_scale = props[:animate_scale]
            animate_size = props[:animate_size]
            aspect_ratio = props[:aspect_ratio]
            badge = props[:badge]
            border_color = props[:border_color]
            border_radius = props[:border_radius]
            border_width = props[:border_width]
            bottom = props[:bottom]
            cell_padding = props[:cell_padding]
            col = props[:col]
            column_widths = props[:column_widths]
            controls = props[:controls]
            data = props[:data]
            default_column_width = props[:default_column_width]
            default_vertical_alignment = props[:default_vertical_alignment]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            height = props[:height]
            inner_borders = props[:inner_borders]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rows = props[:rows]
            rtl = props[:rtl]
            scale = props[:scale]
            size_change_interval = props[:size_change_interval]
            tooltip = props[:tooltip]
            top = props[:top]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_size_change = props[:on_size_change]

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
            props[:border_color] = border_color unless border_color.nil?
            props[:border_radius] = border_radius unless border_radius.nil?
            props[:border_width] = border_width unless border_width.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:cell_padding] = cell_padding unless cell_padding.nil?
            props[:col] = col unless col.nil?
            props[:column_widths] = column_widths unless column_widths.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:default_column_width] = default_column_width unless default_column_width.nil?
            props[:default_vertical_alignment] = default_vertical_alignment unless default_vertical_alignment.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:inner_borders] = inner_borders unless inner_borders.nil?
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
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
