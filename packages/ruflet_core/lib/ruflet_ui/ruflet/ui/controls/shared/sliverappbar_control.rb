# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SliverAppBarControl < Ruflet::Control
          TYPE = "sliverappbar".freeze
          WIRE = "SliverAppBar".freeze

          KEYWORDS = [:actions, :always_show_middle, :automatically_imply_leading, :bgcolor, :border, :bottom, :bottom_height, :center_title, :collapsed_height, :color, :data, :elevation, :expanded_height, :flexible_space, :floating, :key, :leading, :pinned, :previous_page_title, :scrolled_under_elevation, :shadow_color, :snap, :stretch, :title, :toolbar_height, :transition_between_routes, :variant, :visible].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            actions = props[:actions]
            always_show_middle = props[:always_show_middle]
            automatically_imply_leading = props[:automatically_imply_leading]
            bgcolor = props[:bgcolor]
            border = props[:border]
            bottom = props[:bottom]
            bottom_height = props[:bottom_height]
            center_title = props[:center_title]
            collapsed_height = props[:collapsed_height]
            color = props[:color]
            data = props[:data]
            elevation = props[:elevation]
            expanded_height = props[:expanded_height]
            flexible_space = props[:flexible_space]
            floating = props[:floating]
            key = props[:key]
            leading = props[:leading]
            pinned = props[:pinned]
            previous_page_title = props[:previous_page_title]
            scrolled_under_elevation = props[:scrolled_under_elevation]
            shadow_color = props[:shadow_color]
            snap = props[:snap]
            stretch = props[:stretch]
            title = props[:title]
            toolbar_height = props[:toolbar_height]
            transition_between_routes = props[:transition_between_routes]
            variant = props[:variant]
            visible = props[:visible]
            always_show_middle = true if always_show_middle.nil?
            automatically_imply_leading = true if automatically_imply_leading.nil?
            floating = false if floating.nil?
            snap = false if snap.nil?
            stretch = false if stretch.nil?
            transition_between_routes = false if transition_between_routes.nil?
            variant = "small" if variant.nil?

            props = {}
            props[:actions] = actions unless actions.nil?
            props[:always_show_middle] = always_show_middle unless always_show_middle.nil?
            props[:automatically_imply_leading] = automatically_imply_leading unless automatically_imply_leading.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:border] = border unless border.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:bottom_height] = bottom_height unless bottom_height.nil?
            props[:center_title] = center_title unless center_title.nil?
            props[:collapsed_height] = collapsed_height unless collapsed_height.nil?
            props[:color] = color unless color.nil?
            props[:data] = data unless data.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:expanded_height] = expanded_height unless expanded_height.nil?
            props[:flexible_space] = flexible_space unless flexible_space.nil?
            props[:floating] = floating unless floating.nil?
            props[:key] = key unless key.nil?
            props[:leading] = leading unless leading.nil?
            props[:pinned] = pinned unless pinned.nil?
            props[:previous_page_title] = previous_page_title unless previous_page_title.nil?
            props[:scrolled_under_elevation] = scrolled_under_elevation unless scrolled_under_elevation.nil?
            props[:shadow_color] = shadow_color unless shadow_color.nil?
            props[:snap] = snap unless snap.nil?
            props[:stretch] = stretch unless stretch.nil?
            props[:title] = title unless title.nil?
            props[:toolbar_height] = toolbar_height unless toolbar_height.nil?
            props[:transition_between_routes] = transition_between_routes unless transition_between_routes.nil?
            props[:variant] = variant unless variant.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
