# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DragTargetControl < Ruflet::Control
          TYPE = "dragtarget".freeze
          WIRE = "DragTarget".freeze

          def initialize(id: nil, badge: nil, col: nil, content: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, group: nil, key: nil, opacity: nil, rtl: nil, tooltip: nil, visible: nil, on_accept: nil, on_leave: nil, on_move: nil, on_will_accept: nil)
            props = {}
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:group] = group unless group.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_accept] = on_accept unless on_accept.nil?
            props[:on_leave] = on_leave unless on_leave.nil?
            props[:on_move] = on_move unless on_move.nil?
            props[:on_will_accept] = on_will_accept unless on_will_accept.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
