# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CarouselViewControl < Ruflet::Control
          TYPE = "carouselview".freeze
          WIRE = "CarouselView".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :bottom, :col, :consume_max_weight, :controls, :data, :disabled, :elevation, :enable_splash, :expand, :expand_loose, :flex_weights, :height, :horizontal, :initial_item, :item_clip_behavior, :item_extent, :item_snapping, :key, :left, :margin, :offset, :opacity, :overlay_color, :padding, :reverse, :right, :rotate, :rtl, :scale, :shape, :shrink_extent, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_item_click, :on_size_change].freeze

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
            bottom = props[:bottom]
            col = props[:col]
            consume_max_weight = props[:consume_max_weight]
            controls = props[:controls]
            data = props[:data]
            disabled = props[:disabled]
            elevation = props[:elevation]
            enable_splash = props[:enable_splash]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            flex_weights = props[:flex_weights]
            height = props[:height]
            horizontal = props[:horizontal]
            initial_item = props[:initial_item]
            item_clip_behavior = props[:item_clip_behavior]
            item_extent = props[:item_extent]
            item_snapping = props[:item_snapping]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            offset = props[:offset]
            opacity = props[:opacity]
            overlay_color = props[:overlay_color]
            padding = props[:padding]
            reverse = props[:reverse]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            shape = props[:shape]
            shrink_extent = props[:shrink_extent]
            size_change_interval = props[:size_change_interval]
            tooltip = props[:tooltip]
            top = props[:top]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_item_click = props[:on_item_click]
            on_size_change = props[:on_size_change]
            horizontal = true if horizontal.nil?

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
            props[:consume_max_weight] = consume_max_weight unless consume_max_weight.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:enable_splash] = enable_splash unless enable_splash.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:flex_weights] = flex_weights unless flex_weights.nil?
            props[:height] = height unless height.nil?
            props[:horizontal] = horizontal unless horizontal.nil?
            props[:initial_item] = initial_item unless initial_item.nil?
            props[:item_clip_behavior] = item_clip_behavior unless item_clip_behavior.nil?
            props[:item_extent] = item_extent unless item_extent.nil?
            props[:item_snapping] = item_snapping unless item_snapping.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:overlay_color] = overlay_color unless overlay_color.nil?
            props[:padding] = padding unless padding.nil?
            props[:reverse] = reverse unless reverse.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:shape] = shape unless shape.nil?
            props[:shrink_extent] = shrink_extent unless shrink_extent.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_item_click] = on_item_click unless on_item_click.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end

          # Scrolls so the item at `index` becomes the leading (or, for
          # flex_weights, the most prominent) item. Out-of-range indexes clamp.
          def animate_to_item(index, duration: 300, curve: "ease", timeout: 10, on_result: nil)
            args = { "index" => index, "duration" => duration, "curve" => curve }
            runtime_page&.invoke(self, "animate_to_item", args: args, timeout: timeout, on_result: on_result)
          end
        end
      end
    end
  end
end
