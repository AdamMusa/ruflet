# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoBottomSheetControl < Ruflet::Control
          TYPE = "cupertinobottomsheet".freeze
          WIRE = "CupertinoBottomSheet".freeze

          def initialize(id: nil, adaptive: nil, badge: nil, bgcolor: nil, col: nil, content: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, height: nil, key: nil, modal: nil, opacity: nil, open: nil, padding: nil, rtl: nil, tooltip: nil, visible: nil, on_dismiss: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:modal] = modal unless modal.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:open] = open unless open.nil?
            props[:padding] = padding unless padding.nil?
            props[:rtl] = rtl unless rtl.nil?
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
