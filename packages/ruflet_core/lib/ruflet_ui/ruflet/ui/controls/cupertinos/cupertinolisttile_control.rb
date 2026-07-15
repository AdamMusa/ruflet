# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoListTileControl < Ruflet::Control
          TYPE = "cupertinolisttile".freeze
          WIRE = "CupertinoListTile".freeze

          KEYWORDS = [:additional_info, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :bgcolor_activated, :bottom, :col, :data, :disabled, :expand, :expand_loose, :height, :key, :leading, :leading_size, :leading_to_title, :left, :margin, :notched, :offset, :opacity, :padding, :right, :rotate, :rtl, :scale, :size_change_interval, :subtitle, :title, :toggle_inputs, :tooltip, :top, :trailing, :url, :visible, :width, :on_animation_end, :on_click, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            additional_info = props[:additional_info]
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
            bgcolor_activated = props[:bgcolor_activated]
            bottom = props[:bottom]
            col = props[:col]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            height = props[:height]
            key = props[:key]
            leading = props[:leading]
            leading_size = props[:leading_size]
            leading_to_title = props[:leading_to_title]
            left = props[:left]
            margin = props[:margin]
            notched = props[:notched]
            offset = props[:offset]
            opacity = props[:opacity]
            padding = props[:padding]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            size_change_interval = props[:size_change_interval]
            subtitle = props[:subtitle]
            title = props[:title]
            toggle_inputs = props[:toggle_inputs]
            tooltip = props[:tooltip]
            top = props[:top]
            trailing = props[:trailing]
            url = props[:url]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_click = props[:on_click]
            on_size_change = props[:on_size_change]
            raise ArgumentError, "cupertino_list_tile requires title" if title.nil?
            notched = false if notched.nil?
            leading_size = notched ? 30.0 : 28.0 if leading_size.nil?
            leading_to_title = notched ? 12.0 : 16.0 if leading_to_title.nil?
            toggle_inputs = false if toggle_inputs.nil?
            props = {}
            props[:additional_info] = additional_info unless additional_info.nil?
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
            props[:bgcolor_activated] = bgcolor_activated unless bgcolor_activated.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:leading] = leading unless leading.nil?
            props[:leading_size] = leading_size unless leading_size.nil?
            props[:leading_to_title] = leading_to_title unless leading_to_title.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:notched] = notched unless notched.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:subtitle] = subtitle unless subtitle.nil?
            props[:title] = title unless title.nil?
            props[:toggle_inputs] = toggle_inputs unless toggle_inputs.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:trailing] = trailing unless trailing.nil?
            props[:url] = url unless url.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_click] = on_click unless on_click.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
