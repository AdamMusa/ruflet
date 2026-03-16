# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class AlertDialogControl < Ruflet::Control
          TYPE = "alertdialog".freeze
          WIRE = "AlertDialog".freeze

          def initialize(id: nil, action_button_padding: nil, actions: nil, actions_alignment: nil, actions_overflow_button_spacing: nil, actions_padding: nil, adaptive: nil, alignment: nil, badge: nil, barrier_color: nil, bgcolor: nil, clip_behavior: nil, col: nil, content: nil, content_padding: nil, content_text_style: nil, data: nil, disabled: nil, elevation: nil, expand: nil, expand_loose: nil, icon: nil, icon_color: nil, icon_padding: nil, inset_padding: nil, key: nil, modal: nil, opacity: nil, open: nil, rtl: nil, scrollable: nil, semantics_label: nil, shadow_color: nil, shape: nil, title: nil, title_padding: nil, title_text_style: nil, tooltip: nil, visible: nil, on_dismiss: nil)
            props = {}
            props[:action_button_padding] = action_button_padding unless action_button_padding.nil?
            props[:actions] = actions unless actions.nil?
            props[:actions_alignment] = actions_alignment unless actions_alignment.nil?
            props[:actions_overflow_button_spacing] = actions_overflow_button_spacing unless actions_overflow_button_spacing.nil?
            props[:actions_padding] = actions_padding unless actions_padding.nil?
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:alignment] = alignment unless alignment.nil?
            props[:badge] = badge unless badge.nil?
            props[:barrier_color] = barrier_color unless barrier_color.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:content_padding] = content_padding unless content_padding.nil?
            props[:content_text_style] = content_text_style unless content_text_style.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:icon] = icon unless icon.nil?
            props[:icon_color] = icon_color unless icon_color.nil?
            props[:icon_padding] = icon_padding unless icon_padding.nil?
            props[:inset_padding] = inset_padding unless inset_padding.nil?
            props[:key] = key unless key.nil?
            props[:modal] = modal unless modal.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:open] = open unless open.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scrollable] = scrollable unless scrollable.nil?
            props[:semantics_label] = semantics_label unless semantics_label.nil?
            props[:shadow_color] = shadow_color unless shadow_color.nil?
            props[:shape] = shape unless shape.nil?
            props[:title] = title unless title.nil?
            props[:title_padding] = title_padding unless title_padding.nil?
            props[:title_text_style] = title_text_style unless title_text_style.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
