# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SliverGridControl < Ruflet::Control
          TYPE = "slivergrid".freeze
          WIRE = "SliverGrid".freeze

          KEYWORDS = [:bgcolor, :child_aspect_ratio, :controls, :data, :header, :key, :max_extent, :padding, :run_spacing, :runs_count, :spacing, :sticky_header, :visible].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            bgcolor = props[:bgcolor]
            child_aspect_ratio = props[:child_aspect_ratio]
            controls = props[:controls]
            data = props[:data]
            header = props[:header]
            key = props[:key]
            max_extent = props[:max_extent]
            padding = props[:padding]
            run_spacing = props[:run_spacing]
            runs_count = props[:runs_count]
            spacing = props[:spacing]
            sticky_header = props[:sticky_header]
            visible = props[:visible]
            child_aspect_ratio = 1.0 if child_aspect_ratio.nil?
            run_spacing = 10 if run_spacing.nil?
            runs_count = 1 if runs_count.nil?
            spacing = 10 if spacing.nil?
            sticky_header = false if sticky_header.nil?

            props = {}
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:child_aspect_ratio] = child_aspect_ratio unless child_aspect_ratio.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:header] = header unless header.nil?
            props[:key] = key unless key.nil?
            props[:max_extent] = max_extent unless max_extent.nil?
            props[:padding] = padding unless padding.nil?
            props[:run_spacing] = run_spacing unless run_spacing.nil?
            props[:runs_count] = runs_count unless runs_count.nil?
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
