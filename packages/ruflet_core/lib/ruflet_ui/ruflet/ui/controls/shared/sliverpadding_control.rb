# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Insets the slivers it wraps inside a CustomScrollView (Flutter's
        # SliverPadding over a SliverMainAxisGroup): `padding` around one or
        # more slivers, given as `slivers:` or as block children (`controls`).
        # A plain control among them scrolls as a box, as in a CustomScrollView.
        class SliverPaddingControl < Ruflet::Control
          TYPE = "sliverpadding".freeze
          WIRE = "SliverPadding".freeze

          KEYWORDS = [:controls, :data, :key, :padding, :slivers, :visible].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?

            super(type: TYPE, id: id, **props.reject { |_key, value| value.nil? })
          end
        end
      end
    end
  end
end
