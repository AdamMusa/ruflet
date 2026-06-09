# frozen_string_literal: true

module Showcase
  module SectionsMisc
    def build_drawing(page, status)
      strokes = []
      last_point = nil
      drawing_paint = paint(color: "#ff6b6b", stroke_width: 3, style: "stroke", stroke_cap: "round", stroke_join: "round")
      demo_shapes = [
        rect(x: 18, y: 18, width: 72, height: 44, border_radius: 8, paint: paint(color: "#4dabf7", stroke_width: 3, style: "stroke")),
        circle(x: 170, y: 40, radius: 22, paint: paint(color: "#ffd43b", style: "fill")),
        path(
          elements: [
            path_move_to(42, 156),
            path_line_to(92, 112),
            path_line_to(142, 156),
            path_close
          ],
          paint: paint(color: "#69db7c", stroke_width: 4, style: "stroke", stroke_join: "round")
        )
      ]

      drawing_canvas = canvas(
        demo_shapes,
        width: 420,
        height: 260,
        content: gesture_detector(
          on_pan_start: ->(e) {
            pos = extract_pos(e)
            last_point = pos
          },
          on_pan_update: ->(e) {
            pos = extract_pos(e)
            if last_point && pos
              strokes << line(x1: last_point[:x], y1: last_point[:y], x2: pos[:x], y2: pos[:y], paint: drawing_paint)
              page.update(drawing_canvas, shapes: demo_shapes + strokes)
            end
            last_point = pos
          },
          on_pan_end: ->(_e) { last_point = nil },
          drag_interval: 10
        )
      )

      column(spacing: 8, tight: true, children: [status, drawing_canvas])
    end
  end
end
