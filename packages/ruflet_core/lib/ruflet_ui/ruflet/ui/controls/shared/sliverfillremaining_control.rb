# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SliverFillRemainingControl < Ruflet::Control
          TYPE = "sliverfillremaining".freeze
          WIRE = "SliverFillRemaining".freeze

          KEYWORDS = [:content, :data, :fill_overscroll, :has_scroll_body, :key, :visible].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            content = props[:content]
            data = props[:data]
            fill_overscroll = props[:fill_overscroll]
            has_scroll_body = props[:has_scroll_body]
            key = props[:key]
            visible = props[:visible]
            fill_overscroll = false if fill_overscroll.nil?
            has_scroll_body = false if has_scroll_body.nil?

            props = {}
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:fill_overscroll] = fill_overscroll unless fill_overscroll.nil?
            props[:has_scroll_body] = has_scroll_body unless has_scroll_body.nil?
            props[:key] = key unless key.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
