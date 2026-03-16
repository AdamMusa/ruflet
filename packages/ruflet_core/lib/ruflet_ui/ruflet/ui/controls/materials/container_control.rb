# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ContainerControl < Ruflet::Control
          TYPE = "container".freeze
          WIRE = "Container".freeze

          def initialize(id: nil, adaptive: nil, align: nil, alignment: nil, animate: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bgcolor: nil, blend_mode: nil, blur: nil, border: nil, border_radius: nil, bottom: nil, clip_behavior: nil, col: nil, color_filter: nil, content: nil, dark_theme: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, foreground_decoration: nil, gradient: nil, height: nil, ignore_interactions: nil, image: nil, ink: nil, ink_color: nil, key: nil, left: nil, margin: nil, offset: nil, opacity: nil, padding: nil, right: nil, rotate: nil, rtl: nil, scale: nil, shadow: nil, shape: nil, size_change_interval: nil, theme: nil, theme_mode: nil, tooltip: nil, top: nil, url: nil, visible: nil, width: nil, on_animation_end: nil, on_click: nil, on_hover: nil, on_long_press: nil, on_size_change: nil, on_tap_down: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:align] = align unless align.nil?
            props[:alignment] = alignment unless alignment.nil?
            props[:animate] = animate unless animate.nil?
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
            props[:blend_mode] = blend_mode unless blend_mode.nil?
            props[:blur] = blur unless blur.nil?
            props[:border] = border unless border.nil?
            props[:border_radius] = border_radius unless border_radius.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:color_filter] = color_filter unless color_filter.nil?
            props[:content] = content unless content.nil?
            props[:dark_theme] = dark_theme unless dark_theme.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:foreground_decoration] = foreground_decoration unless foreground_decoration.nil?
            props[:gradient] = gradient unless gradient.nil?
            props[:height] = height unless height.nil?
            props[:ignore_interactions] = ignore_interactions unless ignore_interactions.nil?
            props[:image] = image unless image.nil?
            props[:ink] = ink unless ink.nil?
            props[:ink_color] = ink_color unless ink_color.nil?
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
            props[:shadow] = shadow unless shadow.nil?
            props[:shape] = shape unless shape.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:theme] = theme unless theme.nil?
            props[:theme_mode] = theme_mode unless theme_mode.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:url] = url unless url.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_click] = on_click unless on_click.nil?
            props[:on_hover] = on_hover unless on_hover.nil?
            props[:on_long_press] = on_long_press unless on_long_press.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            props[:on_tap_down] = on_tap_down unless on_tap_down.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
