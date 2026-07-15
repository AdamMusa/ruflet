# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoPickerControl < Ruflet::Control
          TYPE = "cupertinopicker".freeze
          WIRE = "CupertinoPicker".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :bottom, :col, :controls, :data, :default_selection_overlay_bgcolor, :diameter_ratio, :disabled, :expand, :expand_loose, :height, :item_extent, :key, :left, :looping, :magnification, :margin, :off_axis_fraction, :offset, :opacity, :right, :rotate, :rtl, :scale, :selected_index, :selection_overlay, :size_change_interval, :squeeze, :tooltip, :top, :use_magnifier, :visible, :width, :on_animation_end, :on_change, :on_size_change].freeze

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
            controls = props[:controls]
            data = props[:data]
            default_selection_overlay_bgcolor = props[:default_selection_overlay_bgcolor]
            diameter_ratio = props[:diameter_ratio]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            height = props[:height]
            item_extent = props[:item_extent]
            key = props[:key]
            left = props[:left]
            looping = props[:looping]
            magnification = props[:magnification]
            margin = props[:margin]
            off_axis_fraction = props[:off_axis_fraction]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            selected_index = props[:selected_index]
            selection_overlay = props[:selection_overlay]
            size_change_interval = props[:size_change_interval]
            squeeze = props[:squeeze]
            tooltip = props[:tooltip]
            top = props[:top]
            use_magnifier = props[:use_magnifier]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_change = props[:on_change]
            on_size_change = props[:on_size_change]
            diameter_ratio = 1.07 if diameter_ratio.nil?
            item_extent = 32.0 if item_extent.nil?
            looping = false if looping.nil?
            magnification = 1.0 if magnification.nil?
            off_axis_fraction = 0.0 if off_axis_fraction.nil?
            selected_index = 0 if selected_index.nil?
            squeeze = 1.45 if squeeze.nil?
            use_magnifier = false if use_magnifier.nil?

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
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:default_selection_overlay_bgcolor] = default_selection_overlay_bgcolor unless default_selection_overlay_bgcolor.nil?
            props[:diameter_ratio] = diameter_ratio unless diameter_ratio.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:item_extent] = item_extent unless item_extent.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:looping] = looping unless looping.nil?
            props[:magnification] = magnification unless magnification.nil?
            props[:margin] = margin unless margin.nil?
            props[:off_axis_fraction] = off_axis_fraction unless off_axis_fraction.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:selected_index] = selected_index unless selected_index.nil?
            props[:selection_overlay] = selection_overlay unless selection_overlay.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:squeeze] = squeeze unless squeeze.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:use_magnifier] = use_magnifier unless use_magnifier.nil?
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
