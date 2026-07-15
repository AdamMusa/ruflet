# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class PopupMenuItemControl < Ruflet::Control
          TYPE = "popupmenuitem".freeze
          WIRE = "PopupMenuItem".freeze

          def initialize(id: nil, badge: nil, checked: nil, col: nil, content: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, height: nil, icon: nil, key: nil, label_text_style: nil, mouse_cursor: nil, opacity: nil, padding: nil, rtl: nil, tooltip: nil, visible: nil, on_click: nil)
            props = {}
            props[:badge] = badge unless badge.nil?
            props[:checked] = checked unless checked.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:icon] = icon unless icon.nil?
            props[:key] = key unless key.nil?
            props[:label_text_style] = label_text_style unless label_text_style.nil?
            props[:mouse_cursor] = mouse_cursor unless mouse_cursor.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_click] = on_click unless on_click.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
