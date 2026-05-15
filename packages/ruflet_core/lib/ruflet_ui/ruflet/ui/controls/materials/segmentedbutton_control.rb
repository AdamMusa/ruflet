# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SegmentedButtonControl < Ruflet::Control
          TYPE = "segmentedbutton".freeze
          WIRE = "SegmentedButton".freeze

          def initialize(id: nil, align: nil, allow_empty_selection: nil, allow_multiple_selection: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bottom: nil, col: nil, data: nil, direction: nil, disabled: nil, expand: nil, expand_loose: nil, height: nil, key: nil, left: nil, margin: nil, offset: nil, opacity: nil, padding: nil, right: nil, rotate: nil, rtl: nil, scale: nil, segments: nil, selected: nil, selected_icon: nil, show_selected_icon: nil, size_change_interval: nil, style: nil, tooltip: nil, top: nil, visible: nil, width: nil, on_animation_end: nil, on_change: nil, on_size_change: nil)
            visible_segments = Array(segments).reject { |segment| segment.respond_to?(:props) && segment.props["visible"] == false }
            raise ArgumentError, "segmented_button requires at least one visible segment" if visible_segments.empty?

            selected_values = selected.nil? ? [] : Array(selected)
            if selected_values.empty? && allow_empty_selection != true
              raise ArgumentError, "segmented_button selected cannot be empty unless allow_empty_selection is true"
            end
            if selected_values.size > 1 && allow_multiple_selection != true
              raise ArgumentError, "segmented_button selected cannot contain multiple values unless allow_multiple_selection is true"
            end

            segment_values = visible_segments.filter_map do |segment|
              segment.respond_to?(:props) ? segment.props["value"] : nil
            end
            missing_values = selected_values - segment_values
            unless missing_values.empty?
              raise ArgumentError, "segmented_button selected values must match segment values"
            end

            props = {}
            props[:align] = align unless align.nil?
            props[:allow_empty_selection] = allow_empty_selection unless allow_empty_selection.nil?
            props[:allow_multiple_selection] = allow_multiple_selection unless allow_multiple_selection.nil?
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
            props[:data] = data unless data.nil?
            props[:direction] = direction unless direction.nil?
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
            props[:segments] = segments unless segments.nil?
            props[:selected] = selected unless selected.nil?
            props[:selected_icon] = selected_icon unless selected_icon.nil?
            props[:show_selected_icon] = show_selected_icon unless show_selected_icon.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:style] = style unless style.nil?
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
