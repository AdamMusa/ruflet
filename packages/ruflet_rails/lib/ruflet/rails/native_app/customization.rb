# frozen_string_literal: true

module Ruflet
  module Rails
    class NativeApp
      CONTROL_PROP_KEYS = {
        appbar: %w[
          actions_padding adaptive automatically_imply_leading bgcolor center_title clip_behavior color data elevation
          elevation_on_scroll exclude_header_semantics force_material_transparency leading_width opacity secondary
          shadow_color shape title_spacing title_text_style toolbar_height toolbar_opacity toolbar_text_style tooltip visible
        ],
        navigation_bar: %w[
          adaptive bgcolor border elevation height indicator_color indicator_shape label_behavior label_padding margin
          overlay_color shadow_color surface_tint_color tooltip visible width
        ],
        navigation_bar_destination: %w[
          adaptive bgcolor data disabled selected_icon tooltip visible
        ],
        navigation_drawer: %w[
          adaptive bgcolor elevation indicator_color indicator_shape opacity shadow_color surface_tint_color tile_padding
          tooltip visible width
        ],
        list_tile: %w[
          adaptive autofocus bgcolor content_padding dense disabled enable_feedback height horizontal_spacing hover_color
          icon_color is_three_line min_height min_leading_width min_vertical_padding selected_color selected_tile_color
          shape splash_color style subtitle_text_style text_color title_alignment title_text_style tooltip visible
          visual_density
        ],
        navigation_rail: %w[
          bgcolor elevation extended group_alignment height indicator_color indicator_shape label_type min_extended_width
          min_width opacity selected_label_text_style tooltip trailing unselected_label_text_style use_indicator visible width
        ],
        navigation_rail_destination: %w[
          indicator_color indicator_shape padding selected_icon tooltip visible
        ],
        icon_button: %w[
          adaptive alignment autofocus bgcolor disabled disabled_color enable_feedback focus_color height highlight_color
          hover_color icon_color icon_size padding selected selected_icon selected_icon_color size_constraints splash_color
          splash_radius style tooltip visible visual_density width
        ],
        icon: %w[color size opacity tooltip visible],
        text: %w[
          color font_family italic max_lines no_wrap opacity selectable semantics_label size style text_align
          theme_style tooltip visible weight
        ],
        alert_dialog: %w[
          action_button_padding actions_alignment actions_overflow_button_spacing actions_padding adaptive alignment
          barrier_color bgcolor clip_behavior content_padding content_text_style elevation icon_color icon_padding
          inset_padding modal opacity open scrollable semantics_label shadow_color shape title_padding title_text_style
          tooltip visible
        ],
        snack_bar: %w[
          action_overflow_threshold adaptive behavior bgcolor clip_behavior close_icon_color dismiss_direction duration
          elevation margin opacity open padding persist shape show_close_icon tooltip visible width
        ],
        bottom_sheet: %w[
          adaptive animation_style barrier_color bgcolor clip_behavior dismissible draggable elevation fullscreen
          maintain_bottom_view_insets_padding opacity open scrollable shape show_drag_handle size_constraints tooltip
          use_safe_area visible
        ],
        container: %w[
          alignment bgcolor border border_radius bottom clip_behavior color expand height left margin opacity padding
          right shadow tooltip top visible width
        ],
        shimmer: %w[base_color direction duration highlight_color loop period visible]
      }.freeze

      INTERNAL_PROP_KEYS = %w[
        action actions component confirm content files haptic href icon items label leading loading message mode nav
        payload selected subject text title toast toast_duration type uri url value
      ].freeze

      private

      def ruflet_props_for(control, source, except: [])
        return {} unless source.is_a?(Hash)

        raw = {}
        raw.merge!(stringify_hash(source["props"])) if source["props"].is_a?(Hash)
        raw.merge!(stringify_hash(source))
        rejected = INTERNAL_PROP_KEYS + Array(except).map(&:to_s)
        allowed = CONTROL_PROP_KEYS.fetch(control).map(&:to_s)
        raw.each_with_object({}) do |(key, value), props|
          next if value.nil?
          next if rejected.include?(key.to_s)
          next unless allowed.include?(key.to_s)

          props[key.to_sym] = ruflet_stringify_nested(value)
        end
      end

      def nested_ruflet_props(source, *keys, control:)
        return {} unless source.is_a?(Hash)

        keys.each do |key|
          value = source[key.to_s]
          return ruflet_props_for(control, value) if value.is_a?(Hash)
        end
        {}
      end

      def stringify_hash(value)
        value.each_with_object({}) { |(key, nested), out| out[key.to_s] = nested }
      end

      def ruflet_stringify_nested(value)
        case value
        when Hash
          value.each_with_object({}) { |(key, nested), out| out[key.to_s] = ruflet_stringify_nested(nested) }
        when Array
          value.map { |nested| ruflet_stringify_nested(nested) }
        else
          value
        end
      end
    end
  end
end
