# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ResponsiveRowControl < Ruflet::Control
          TYPE = "responsiverow".freeze
          WIRE = "ResponsiveRow".freeze

          KEYWORDS = [:adaptive, :align, :alignment, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :breakpoints, :col, :columns, :controls, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :run_spacing, :scale, :size_change_interval, :spacing, :tooltip, :top, :vertical_alignment, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            adaptive = props[:adaptive]
            align = props[:align]
            alignment = props[:alignment]
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
            bottom = props[:bottom]
            breakpoints = props[:breakpoints]
            col = props[:col]
            columns = props[:columns]
            controls = props[:controls]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            height = props[:height]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            run_spacing = props[:run_spacing]
            scale = props[:scale]
            size_change_interval = props[:size_change_interval]
            spacing = props[:spacing]
            tooltip = props[:tooltip]
            top = props[:top]
            vertical_alignment = props[:vertical_alignment]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_size_change = props[:on_size_change]
            alignment = "start" if alignment.nil?
            breakpoints = { "xs" => 0, "sm" => 576, "md" => 768, "lg" => 992, "xl" => 1200, "xxl" => 1400 } if breakpoints.nil?
            columns = 12 if columns.nil?
            run_spacing = 10 if run_spacing.nil?
            spacing = 10 if spacing.nil?
            vertical_alignment = "start" if vertical_alignment.nil?

            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:align] = align unless align.nil?
            props[:alignment] = alignment unless alignment.nil?
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
            props[:bottom] = bottom unless bottom.nil?
            props[:breakpoints] = breakpoints unless breakpoints.nil?
            props[:col] = col unless col.nil?
            props[:columns] = columns unless columns.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:run_spacing] = run_spacing unless run_spacing.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:spacing] = spacing unless spacing.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:vertical_alignment] = vertical_alignment unless vertical_alignment.nil?
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
