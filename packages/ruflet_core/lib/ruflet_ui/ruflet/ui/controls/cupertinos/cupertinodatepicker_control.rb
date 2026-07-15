# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoDatePickerControl < Ruflet::Control
          TYPE = "cupertinodatepicker".freeze
          WIRE = "CupertinoDatePicker".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :bottom, :col, :data, :date_order, :date_picker_mode, :disabled, :expand, :expand_loose, :first_date, :height, :item_extent, :key, :last_date, :left, :locale, :margin, :maximum_year, :minimum_year, :minute_interval, :offset, :opacity, :right, :rotate, :rtl, :scale, :show_day_of_week, :size_change_interval, :tooltip, :top, :use_24h_format, :value, :visible, :width, :on_animation_end, :on_change, :on_size_change].freeze

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
            data = props[:data]
            date_order = props[:date_order]
            date_picker_mode = props[:date_picker_mode]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            first_date = props[:first_date]
            height = props[:height]
            item_extent = props[:item_extent]
            key = props[:key]
            last_date = props[:last_date]
            left = props[:left]
            locale = props[:locale]
            margin = props[:margin]
            maximum_year = props[:maximum_year]
            minimum_year = props[:minimum_year]
            minute_interval = props[:minute_interval]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            show_day_of_week = props[:show_day_of_week]
            size_change_interval = props[:size_change_interval]
            tooltip = props[:tooltip]
            top = props[:top]
            use_24h_format = props[:use_24h_format]
            value = props[:value]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_change = props[:on_change]
            on_size_change = props[:on_size_change]
            date_picker_mode = "date_and_time" if date_picker_mode.nil?
            item_extent = 32.0 if item_extent.nil?
            minimum_year = 1 if minimum_year.nil?
            minute_interval = 1 if minute_interval.nil?
            show_day_of_week = false if show_day_of_week.nil?
            use_24h_format = false if use_24h_format.nil?

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
            props[:data] = data unless data.nil?
            props[:date_order] = date_order unless date_order.nil?
            props[:date_picker_mode] = date_picker_mode unless date_picker_mode.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:first_date] = first_date unless first_date.nil?
            props[:height] = height unless height.nil?
            props[:item_extent] = item_extent unless item_extent.nil?
            props[:key] = key unless key.nil?
            props[:last_date] = last_date unless last_date.nil?
            props[:left] = left unless left.nil?
            props[:locale] = locale unless locale.nil?
            props[:margin] = margin unless margin.nil?
            props[:maximum_year] = maximum_year unless maximum_year.nil?
            props[:minimum_year] = minimum_year unless minimum_year.nil?
            props[:minute_interval] = minute_interval unless minute_interval.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:show_day_of_week] = show_day_of_week unless show_day_of_week.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:use_24h_format] = use_24h_format unless use_24h_format.nil?
            props[:value] = value unless value.nil?
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
