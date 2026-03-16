# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class InteractiveViewerControl < Ruflet::Control
          TYPE = "interactiveviewer".freeze
          WIRE = "InteractiveViewer".freeze

          def initialize(id: nil, align: nil, alignment: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bottom: nil, boundary_margin: nil, clip_behavior: nil, col: nil, constrained: nil, content: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, height: nil, interaction_end_friction_coefficient: nil, interaction_update_interval: nil, key: nil, left: nil, margin: nil, max_scale: nil, min_scale: nil, offset: nil, opacity: nil, pan_enabled: nil, right: nil, rotate: nil, rtl: nil, scale: nil, scale_enabled: nil, scale_factor: nil, size_change_interval: nil, tooltip: nil, top: nil, trackpad_scroll_causes_scale: nil, visible: nil, width: nil, on_animation_end: nil, on_interaction_end: nil, on_interaction_start: nil, on_interaction_update: nil, on_size_change: nil)
            props = {}
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
            props[:boundary_margin] = boundary_margin unless boundary_margin.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:constrained] = constrained unless constrained.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:interaction_end_friction_coefficient] = interaction_end_friction_coefficient unless interaction_end_friction_coefficient.nil?
            props[:interaction_update_interval] = interaction_update_interval unless interaction_update_interval.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:max_scale] = max_scale unless max_scale.nil?
            props[:min_scale] = min_scale unless min_scale.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:pan_enabled] = pan_enabled unless pan_enabled.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:scale_enabled] = scale_enabled unless scale_enabled.nil?
            props[:scale_factor] = scale_factor unless scale_factor.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:trackpad_scroll_causes_scale] = trackpad_scroll_causes_scale unless trackpad_scroll_causes_scale.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_interaction_end] = on_interaction_end unless on_interaction_end.nil?
            props[:on_interaction_start] = on_interaction_start unless on_interaction_start.nil?
            props[:on_interaction_update] = on_interaction_update unless on_interaction_update.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
