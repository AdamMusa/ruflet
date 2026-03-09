# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class IconControl < Ruflet::Control
          TYPE = "icon".freeze
          WIRE = "Icon".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, apply_text_scaling: nil, aspect_ratio: nil, badge: nil, blend_mode: nil, bottom: nil, col: nil, color: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, fill: nil, grade: nil, height: nil, icon: nil, key: nil, left: nil, margin: nil, offset: nil, opacity: nil, optical_size: nil, right: nil, rotate: nil, rtl: nil, scale: nil, semantics_label: nil, shadows: nil, size: nil, size_change_interval: nil, tooltip: nil, top: nil, visible: nil, weight: nil, width: nil, on_animation_end: nil, on_size_change: nil)
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
            props[:apply_text_scaling] = apply_text_scaling unless apply_text_scaling.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:badge] = badge unless badge.nil?
            props[:blend_mode] = blend_mode unless blend_mode.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:color] = color unless color.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:fill] = fill unless fill.nil?
            props[:grade] = grade unless grade.nil?
            props[:height] = height unless height.nil?
            props[:icon] = icon unless icon.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:optical_size] = optical_size unless optical_size.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:semantics_label] = semantics_label unless semantics_label.nil?
            props[:shadows] = shadows unless shadows.nil?
            props[:size] = size unless size.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:weight] = weight unless weight.nil?
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
