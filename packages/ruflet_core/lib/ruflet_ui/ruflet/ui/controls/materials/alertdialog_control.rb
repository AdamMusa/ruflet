# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class AlertDialogControl < Ruflet::Control
          TYPE = "alertdialog".freeze
          WIRE = "AlertDialog".freeze

          KEYWORDS = [:action_button_padding, :actions, :actions_alignment, :actions_overflow_button_spacing, :actions_padding, :adaptive, :alignment, :badge, :barrier_color, :bgcolor, :clip_behavior, :col, :content, :content_padding, :content_text_style, :data, :disabled, :elevation, :expand, :expand_loose, :icon, :icon_color, :icon_padding, :inset_padding, :key, :modal, :opacity, :open, :rtl, :scrollable, :semantics_label, :shadow_color, :shape, :title, :title_padding, :title_text_style, :tooltip, :visible, :on_dismiss].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end
        end
      end
    end
  end
end
