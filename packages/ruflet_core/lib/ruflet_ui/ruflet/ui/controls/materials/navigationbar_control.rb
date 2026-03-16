# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class NavigationBarControl < Ruflet::Control
          TYPE = "navigationbar".freeze
          WIRE = "NavigationBar".freeze

          def initialize(id: nil, adaptive: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, animation_duration: nil, aspect_ratio: nil, badge: nil, bgcolor: nil, border: nil, bottom: nil, col: nil, data: nil, destinations: nil, disabled: nil, elevation: nil, expand: nil, expand_loose: nil, height: nil, indicator_color: nil, indicator_shape: nil, key: nil, label_behavior: nil, label_padding: nil, left: nil, margin: nil, offset: nil, opacity: nil, overlay_color: nil, right: nil, rotate: nil, rtl: nil, scale: nil, selected_index: nil, shadow_color: nil, size_change_interval: nil, tooltip: nil, top: nil, visible: nil, width: nil, on_animation_end: nil, on_change: nil, on_size_change: nil)
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
            props[:animation_duration] = animation_duration unless animation_duration.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:border] = border unless border.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:destinations] = destinations unless destinations.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:indicator_color] = indicator_color unless indicator_color.nil?
            props[:indicator_shape] = indicator_shape unless indicator_shape.nil?
            props[:key] = key unless key.nil?
            props[:label_behavior] = label_behavior unless label_behavior.nil?
            props[:label_padding] = label_padding unless label_padding.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:overlay_color] = overlay_color unless overlay_color.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:selected_index] = selected_index unless selected_index.nil?
            props[:shadow_color] = shadow_color unless shadow_color.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
