# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SliverListControl < Ruflet::Control
          TYPE = "sliverlist".freeze
          WIRE = "SliverList".freeze

          KEYWORDS = [:bgcolor, :build_controls_on_demand, :controls, :data, :divider_thickness, :header, :item_extent, :key, :padding, :spacing, :sticky_header, :visible].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            bgcolor = props[:bgcolor]
            build_controls_on_demand = props[:build_controls_on_demand]
            controls = props[:controls]
            data = props[:data]
            divider_thickness = props[:divider_thickness]
            header = props[:header]
            item_extent = props[:item_extent]
            key = props[:key]
            padding = props[:padding]
            spacing = props[:spacing]
            sticky_header = props[:sticky_header]
            visible = props[:visible]
            build_controls_on_demand = true if build_controls_on_demand.nil?
            divider_thickness = 0 if divider_thickness.nil?
            spacing = 0 if spacing.nil?
            sticky_header = false if sticky_header.nil?

            props = {}
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:build_controls_on_demand] = build_controls_on_demand unless build_controls_on_demand.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:divider_thickness] = divider_thickness unless divider_thickness.nil?
            props[:header] = header unless header.nil?
            props[:item_extent] = item_extent unless item_extent.nil?
            props[:key] = key unless key.nil?
            props[:padding] = padding unless padding.nil?
            props[:spacing] = spacing unless spacing.nil?
            props[:sticky_header] = sticky_header unless sticky_header.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
