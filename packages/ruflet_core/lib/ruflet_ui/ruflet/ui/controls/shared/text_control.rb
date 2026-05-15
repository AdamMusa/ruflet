# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TextControl < Ruflet::Control
          TYPE = "text".freeze
          WIRE = "Text".freeze

          def initialize(id: nil, alignment: nil, bgcolor: nil, color: nil, data: nil, ellipsis: nil, enable_interactive_selection: nil, font_family: nil, font_family_fallback: nil, italic: nil, key: nil, max_lines: nil, max_width: nil, no_wrap: nil, overflow: nil, rotate: nil, selectable: nil, selection_cursor_color: nil, selection_cursor_height: nil, selection_cursor_width: nil, semantics_label: nil, show_selection_cursor: nil, size: nil, spans: nil, style: nil, text_align: nil, theme_style: nil, value: nil, weight: nil, x: nil, y: nil, on_selection_change: nil, on_tap: nil)
            props = {}
            props[:alignment] = alignment unless alignment.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:color] = color unless color.nil?
            props[:data] = data unless data.nil?
            props[:ellipsis] = ellipsis unless ellipsis.nil?
            props[:enable_interactive_selection] = enable_interactive_selection unless enable_interactive_selection.nil?
            props[:font_family] = font_family unless font_family.nil?
            props[:font_family_fallback] = font_family_fallback unless font_family_fallback.nil?
            props[:italic] = italic unless italic.nil?
            props[:key] = key unless key.nil?
            props[:max_lines] = max_lines unless max_lines.nil?
            props[:max_width] = max_width unless max_width.nil?
            props[:no_wrap] = no_wrap unless no_wrap.nil?
            props[:overflow] = overflow unless overflow.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:selectable] = selectable unless selectable.nil?
            props[:selection_cursor_color] = selection_cursor_color unless selection_cursor_color.nil?
            props[:selection_cursor_height] = selection_cursor_height unless selection_cursor_height.nil?
            props[:selection_cursor_width] = selection_cursor_width unless selection_cursor_width.nil?
            props[:semantics_label] = semantics_label unless semantics_label.nil?
            props[:show_selection_cursor] = show_selection_cursor unless show_selection_cursor.nil?
            props[:size] = size unless size.nil?
            props[:spans] = spans unless spans.nil?
            props[:style] = style unless style.nil?
            props[:text_align] = text_align unless text_align.nil?
            props[:theme_style] = theme_style unless theme_style.nil?
            props[:value] = value unless value.nil?
            props[:weight] = weight unless weight.nil?
            props[:x] = x unless x.nil?
            props[:y] = y unless y.nil?
            props[:on_selection_change] = on_selection_change unless on_selection_change.nil?
            props[:on_tap] = on_tap unless on_tap.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
