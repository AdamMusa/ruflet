# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoContextMenuActionControl < Ruflet::Control
          TYPE = "cupertinocontextmenuaction".freeze
          WIRE = "CupertinoContextMenuAction".freeze

          def initialize(id: nil, adaptive: nil, badge: nil, col: nil, content: nil, data: nil, default: nil, destructive: nil, disabled: nil, expand: nil, expand_loose: nil, key: nil, opacity: nil, rtl: nil, tooltip: nil, trailing_icon: nil, visible: nil, on_click: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:default] = default unless default.nil?
            props[:destructive] = destructive unless destructive.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:trailing_icon] = trailing_icon unless trailing_icon.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_click] = on_click unless on_click.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
