# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoAlertDialogControl < Ruflet::Control
          TYPE = "cupertinoalertdialog".freeze
          WIRE = "CupertinoAlertDialog".freeze

          def initialize(id: nil, actions: nil, adaptive: nil, badge: nil, barrier_color: nil, col: nil, content: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, inset_animation: nil, key: nil, modal: nil, opacity: nil, open: nil, rtl: nil, title: nil, tooltip: nil, visible: nil, on_dismiss: nil)
            props = {}
            props[:actions] = actions unless actions.nil?
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:barrier_color] = barrier_color unless barrier_color.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:inset_animation] = inset_animation unless inset_animation.nil?
            props[:key] = key unless key.nil?
            props[:modal] = modal unless modal.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:open] = open unless open.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:title] = title unless title.nil?
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
