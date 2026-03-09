# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ProgressRingControl < Ruflet::Control
          TYPE = "progressring".freeze
          WIRE = "ProgressRing".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bgcolor: nil, bottom: nil, col: nil, color: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, height: nil, key: nil, left: nil, margin: nil, offset: nil, opacity: nil, padding: nil, right: nil, rotate: nil, rtl: nil, scale: nil, semantics_label: nil, semantics_value: nil, size_change_interval: nil, size_constraints: nil, stroke_align: nil, stroke_cap: nil, stroke_width: nil, tooltip: nil, top: nil, track_gap: nil, value: nil, visible: nil, width: nil, year_2023: nil, on_animation_end: nil, on_size_change: nil)
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
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:color] = color unless color.nil?
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
            props[:padding] = padding unless padding.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:semantics_label] = semantics_label unless semantics_label.nil?
            props[:semantics_value] = semantics_value unless semantics_value.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:size_constraints] = size_constraints unless size_constraints.nil?
            props[:stroke_align] = stroke_align unless stroke_align.nil?
            props[:stroke_cap] = stroke_cap unless stroke_cap.nil?
            props[:stroke_width] = stroke_width unless stroke_width.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:track_gap] = track_gap unless track_gap.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:year_2023] = year_2023 unless year_2023.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
