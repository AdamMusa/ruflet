# frozen_string_literal: true

module RufletStudio
  module SectionsMisc
    def build_drawing(page, status)
      strokes = []
      last_point = nil
      next_shape_id = 1

      canvas = control(
        :canvas,
        width: 260,
        height: 260,
        shapes: [],
        content: gesture_detector(
          on_pan_start: ->(e) {
            pos = extract_pos(e)
            last_point = pos
            page.update(status, value: "Canvas pan start: #{fmt_pos(e)}")
          },
          on_pan_update: ->(e) {
            pos = extract_pos(e)
            if last_point && pos
              strokes << {
                "type" => "line",
                "id" => next_shape_id,
                "x1" => last_point[:x],
                "y1" => last_point[:y],
                "x2" => pos[:x],
                "y2" => pos[:y],
                "paint" => { "stroke_width" => 3, "color" => "#ff6b6b", "style" => "stroke" }
              }
              next_shape_id += 1
              page.update(canvas, shapes: strokes)
            end
            last_point = pos
            page.update(status, value: "Canvas pan update: #{fmt_pos(e)}")
          },
          on_pan_end: ->(_e) { last_point = nil },
          drag_interval: 10
        )
      )

      column(spacing: 8, tight: true, controls: [status, canvas])
    end
  end
end
