# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SliverToBoxAdapterControl < Ruflet::Control
          TYPE = "slivertoboxadapter".freeze
          WIRE = "SliverToBoxAdapter".freeze

          KEYWORDS = [:content, :data, :key, :visible].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            content = props[:content]
            data = props[:data]
            key = props[:key]
            visible = props[:visible]

            props = {}
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
