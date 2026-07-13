# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DismissibleControl < Ruflet::Control
          TYPE = "dismissible".freeze
          WIRE = "Dismissible".freeze

          KEYWORDS = [:adaptive, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :background, :badge, :bottom, :col, :content, :cross_axis_end_offset, :data, :disabled, :dismiss_direction, :dismiss_thresholds, :expand, :expand_loose, :height, :key, :left, :margin, :movement_duration, :offset, :opacity, :resize_duration, :right, :rotate, :rtl, :scale, :secondary_background, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_confirm_dismiss, :on_dismiss, :on_resize, :on_size_change, :on_update].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            adaptive = props[:adaptive]
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
            background = props[:background]
            badge = props[:badge]
            bottom = props[:bottom]
            col = props[:col]
            content = props[:content]
            cross_axis_end_offset = props[:cross_axis_end_offset]
            data = props[:data]
            disabled = props[:disabled]
            dismiss_direction = props[:dismiss_direction]
            dismiss_thresholds = props[:dismiss_thresholds]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            height = props[:height]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            movement_duration = props[:movement_duration]
            offset = props[:offset]
            opacity = props[:opacity]
            resize_duration = props[:resize_duration]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            secondary_background = props[:secondary_background]
            size_change_interval = props[:size_change_interval]
            tooltip = props[:tooltip]
            top = props[:top]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_confirm_dismiss = props[:on_confirm_dismiss]
            on_dismiss = props[:on_dismiss]
            on_resize = props[:on_resize]
            on_size_change = props[:on_size_change]
            on_update = props[:on_update]
            raise ArgumentError, "dismissible requires content" if content.nil?

            cross_axis_end_offset = 0.0 if cross_axis_end_offset.nil?
            dismiss_direction = "horizontal" if dismiss_direction.nil?
            dismiss_thresholds = {} if dismiss_thresholds.nil?
            movement_duration = 200 if movement_duration.nil?
            resize_duration = 300 if resize_duration.nil?

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
            props[:background] = background unless background.nil?
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:cross_axis_end_offset] = cross_axis_end_offset unless cross_axis_end_offset.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:dismiss_direction] = dismiss_direction unless dismiss_direction.nil?
            props[:dismiss_thresholds] = dismiss_thresholds unless dismiss_thresholds.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:movement_duration] = movement_duration unless movement_duration.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:resize_duration] = resize_duration unless resize_duration.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:secondary_background] = secondary_background unless secondary_background.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_confirm_dismiss] = on_confirm_dismiss unless on_confirm_dismiss.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            props[:on_resize] = on_resize unless on_resize.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            props[:on_update] = on_update unless on_update.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
