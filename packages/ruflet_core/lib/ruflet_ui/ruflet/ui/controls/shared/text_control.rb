# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TextControl < Ruflet::Control
          TYPE = "text".freeze
          WIRE = "Text".freeze

          def initialize(id: nil, alignment: nil, data: nil, ellipsis: nil, key: nil, max_lines: nil, max_width: nil, rotate: nil, spans: nil, style: nil, text_align: nil, value: nil, x: nil, y: nil)
            props = {}
            props[:alignment] = alignment unless alignment.nil?
            props[:data] = data unless data.nil?
            props[:ellipsis] = ellipsis unless ellipsis.nil?
            props[:key] = key unless key.nil?
            props[:max_lines] = max_lines unless max_lines.nil?
            props[:max_width] = max_width unless max_width.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:spans] = spans unless spans.nil?
            props[:style] = style unless style.nil?
            props[:text_align] = text_align unless text_align.nil?
            props[:value] = value unless value.nil?
            props[:x] = x unless x.nil?
            props[:y] = y unless y.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
