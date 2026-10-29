# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DraggableScrollableSheetControl < Ruflet::Control
          TYPE = "draggablescrollablesheet".freeze
          WIRE = "DraggableScrollableSheet".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :border_radius, :bottom, :col, :controls, :data, :disabled, :elevation, :expand, :expand_loose, :extent_change_interval, :header, :height, :initial_child_size, :key, :left, :margin, :max_child_size, :min_child_size, :offset, :opacity, :padding, :right, :rotate, :rtl, :scale, :should_close_on_min_extent, :show_drag_handle, :size_change_interval, :snap, :snap_animation_duration, :snap_sizes, :spacing, :tooltip, :top, :visible, :width, :on_animation_end, :on_extent_change, :on_size_change].freeze

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
            bgcolor = props[:bgcolor]
            border_radius = props[:border_radius]
            bottom = props[:bottom]
            col = props[:col]
            controls = props[:controls]
            data = props[:data]
            disabled = props[:disabled]
            elevation = props[:elevation]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            extent_change_interval = props[:extent_change_interval]
            header = props[:header]
            height = props[:height]
            initial_child_size = props[:initial_child_size]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            max_child_size = props[:max_child_size]
            min_child_size = props[:min_child_size]
            offset = props[:offset]
            opacity = props[:opacity]
            padding = props[:padding]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            should_close_on_min_extent = props[:should_close_on_min_extent]
            show_drag_handle = props[:show_drag_handle]
            size_change_interval = props[:size_change_interval]
            snap = props[:snap]
            snap_animation_duration = props[:snap_animation_duration]
            snap_sizes = props[:snap_sizes]
            spacing = props[:spacing]
            tooltip = props[:tooltip]
            top = props[:top]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_extent_change = props[:on_extent_change]
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
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:border_radius] = border_radius unless border_radius.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:extent_change_interval] = extent_change_interval unless extent_change_interval.nil?
            props[:header] = header unless header.nil?
            props[:height] = height unless height.nil?
            props[:initial_child_size] = initial_child_size unless initial_child_size.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:max_child_size] = max_child_size unless max_child_size.nil?
            props[:min_child_size] = min_child_size unless min_child_size.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:should_close_on_min_extent] = should_close_on_min_extent unless should_close_on_min_extent.nil?
            props[:show_drag_handle] = show_drag_handle unless show_drag_handle.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:snap] = snap unless snap.nil?
            props[:snap_animation_duration] = snap_animation_duration unless snap_animation_duration.nil?
            props[:snap_sizes] = snap_sizes unless snap_sizes.nil?
            props[:spacing] = spacing unless spacing.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_extent_change] = on_extent_change unless on_extent_change.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end

          # Animates the sheet to +size+ (a fraction of its parent's height).
          # No-op until the sheet is on screen.
          def animate_to(size, duration: 300, curve: "easeOut", timeout: 10, on_result: nil)
            args = { "size" => size, "duration" => duration, "curve" => curve }
            runtime_page&.invoke(self, "animate_to", args: args, timeout: timeout, on_result: on_result)
          end

          # Moves the sheet to +size+ (a fraction of its parent's height) at once.
          def jump_to(size, timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "jump_to", args: { "size" => size }, timeout: timeout, on_result: on_result)
          end
        end
      end
    end
  end
end
