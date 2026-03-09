# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DraggableControl < Ruflet::Control
          TYPE = "draggable".freeze
          WIRE = "Draggable".freeze

          def initialize(id: nil, affinity: nil, axis: nil, badge: nil, col: nil, content: nil, content_feedback: nil, content_when_dragging: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, group: nil, key: nil, max_simultaneous_drags: nil, opacity: nil, rtl: nil, tooltip: nil, visible: nil, on_drag_complete: nil, on_drag_start: nil)
            props = {}
            props[:affinity] = affinity unless affinity.nil?
            props[:axis] = axis unless axis.nil?
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:content_feedback] = content_feedback unless content_feedback.nil?
            props[:content_when_dragging] = content_when_dragging unless content_when_dragging.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:group] = group unless group.nil?
            props[:key] = key unless key.nil?
            props[:max_simultaneous_drags] = max_simultaneous_drags unless max_simultaneous_drags.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_drag_complete] = on_drag_complete unless on_drag_complete.nil?
            props[:on_drag_start] = on_drag_start unless on_drag_start.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
