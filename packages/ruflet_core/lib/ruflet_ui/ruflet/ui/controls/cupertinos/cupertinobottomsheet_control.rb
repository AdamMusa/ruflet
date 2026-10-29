# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoBottomSheetControl < Ruflet::Control
          TYPE = "cupertinobottomsheet".freeze
          WIRE = "BottomSheet".freeze

          def initialize(id: nil, adaptive: nil, badge: nil, barrier_color: nil, bgcolor: nil, col: nil, content: nil, data: nil, disabled: nil, dismissible: nil, draggable: nil, expand: nil, expand_loose: nil, fullscreen: nil, height: nil, key: nil, maintain_bottom_view_insets_padding: nil, modal: nil, opacity: nil, open: nil, padding: nil, rtl: nil, scrollable: nil, show_drag_handle: nil, size_constraints: nil, tooltip: nil, use_safe_area: nil, visible: nil, on_dismiss: nil)
            raise ArgumentError, "cupertino_bottom_sheet content is required" if content.nil?

            modal = false if modal.nil?

            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:barrier_color] = barrier_color unless barrier_color.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:dismissible] = dismissible unless dismissible.nil?
            props[:draggable] = draggable unless draggable.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:fullscreen] = fullscreen unless fullscreen.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:maintain_bottom_view_insets_padding] = maintain_bottom_view_insets_padding unless maintain_bottom_view_insets_padding.nil?
            props[:modal] = modal unless modal.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:open] = open unless open.nil?
            props[:padding] = padding unless padding.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scrollable] = scrollable unless scrollable.nil?
            props[:show_drag_handle] = show_drag_handle unless show_drag_handle.nil?
            props[:size_constraints] = size_constraints unless size_constraints.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:use_safe_area] = use_safe_area unless use_safe_area.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
