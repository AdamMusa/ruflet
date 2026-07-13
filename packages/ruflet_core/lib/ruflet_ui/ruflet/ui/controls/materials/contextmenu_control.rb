# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ContextMenuControl < Ruflet::Control
          TYPE = "contextmenu".freeze
          WIRE = "ContextMenu".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :content, :data, :disabled, :expand, :expand_loose, :height, :items, :key, :left, :margin, :offset, :opacity, :primary_items, :primary_trigger, :right, :rotate, :rtl, :scale, :secondary_items, :secondary_trigger, :size_change_interval, :tertiary_items, :tertiary_trigger, :tooltip, :top, :visible, :width, :on_animation_end, :on_dismiss, :on_select, :on_size_change].freeze

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
            bottom = props[:bottom]
            col = props[:col]
            content = props[:content]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            height = props[:height]
            items = props[:items]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            offset = props[:offset]
            opacity = props[:opacity]
            primary_items = props[:primary_items]
            primary_trigger = props[:primary_trigger]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            secondary_items = props[:secondary_items]
            secondary_trigger = props[:secondary_trigger]
            size_change_interval = props[:size_change_interval]
            tertiary_items = props[:tertiary_items]
            tertiary_trigger = props[:tertiary_trigger]
            tooltip = props[:tooltip]
            top = props[:top]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_dismiss = props[:on_dismiss]
            on_select = props[:on_select]
            on_size_change = props[:on_size_change]
            raise ArgumentError, "context_menu requires content" if content.nil?

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
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:items] = items unless items.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:primary_items] = primary_items unless primary_items.nil?
            props[:primary_trigger] = primary_trigger unless primary_trigger.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:secondary_items] = secondary_items unless secondary_items.nil?
            props[:secondary_trigger] = secondary_trigger unless secondary_trigger.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tertiary_items] = tertiary_items unless tertiary_items.nil?
            props[:tertiary_trigger] = tertiary_trigger unless tertiary_trigger.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            props[:on_select] = on_select unless on_select.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end

          def open(position: nil, timeout: 10, on_result: nil)
            args = {}
            args["position"] = stringify_hash_keys(position) unless position.nil?
            runtime_page&.invoke(self, "open", args: args, timeout: timeout, on_result: on_result)
          end

          private

          def stringify_hash_keys(value)
            return value.map { |item| stringify_hash_keys(item) } if value.is_a?(Array)
            return value.each_with_object({}) { |(key, child), result| result[key.to_s] = stringify_hash_keys(child) } if value.is_a?(Hash)

            value
          end
        end
      end
    end
  end
end
