# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoDatePickerControl < Ruflet::Control
          TYPE = "cupertinodatepicker".freeze
          WIRE = "CupertinoDatePicker".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bgcolor: nil, bottom: nil, col: nil, data: nil, date_order: nil, date_picker_mode: nil, disabled: nil, expand: nil, expand_loose: nil, first_date: nil, height: nil, item_extent: nil, key: nil, last_date: nil, left: nil, locale: nil, margin: nil, maximum_year: nil, minimum_year: nil, minute_interval: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, scale: nil, show_day_of_week: nil, size_change_interval: nil, tooltip: nil, top: nil, use_24h_format: nil, value: nil, visible: nil, width: nil, on_animation_end: nil, on_change: nil, on_size_change: nil)
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
