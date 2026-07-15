# frozen_string_literal: true

require_relative "test_helper"

class CanvasDrawingCompatibilityTest < Minitest::Test
  def test_canvas_serializes_flet_shape_controls_in_shapes_slot
    drawing_paint = Ruflet.paint(
      color: "#ff6b6b",
      stroke_width: 3,
      style: "stroke",
      stroke_cap: "round",
      stroke_join: "round"
    )

    canvas = Ruflet.canvas(
      [
        Ruflet.line(x1: 1, y1: 2, x2: 3, y2: 4, paint: drawing_paint),
        Ruflet.circle(x: 12, y: 18, radius: 7, paint: drawing_paint),
        Ruflet.rect(x: 20, y: 24, width: 60, height: 30, border_radius: 4, paint: drawing_paint),
        Ruflet.path(
          elements: [
            Ruflet.path_move_to(4, 4),
            Ruflet.path_line_to(14, 10),
            Ruflet.path_close
          ],
          paint: drawing_paint
        )
      ],
      width: 300,
      height: 200,
      resize_interval: 16,
      on_resize: ->(_event) {}
    )

    patch = canvas.to_patch

    assert_equal "Canvas", patch["_c"]
    assert_equal 300, patch["width"]
    assert_equal 200, patch["height"]
    assert_equal 16, patch["resize_interval"]
    assert_equal true, patch["on_resize"]
    refute patch.key?("controls")

    shapes = patch.fetch("shapes")
    assert_equal %w[Line Circle Rect Path], shapes.map { |shape| shape["_c"] }
    assert_equal(
      {
        "color" => "#ff6b6b",
        "stroke_width" => 3,
        "style" => "stroke",
        "stroke_cap" => "round",
        "stroke_join" => "round"
      },
      shapes.first.fetch("paint")
    )
    assert_equal(
      [
        { "_type" => "MoveTo", "x" => 4, "y" => 4 },
        { "_type" => "LineTo", "x" => 14, "y" => 10 },
        { "_type" => "Close" }
      ],
      shapes.last.fetch("elements")
    )
  end

  def test_path_element_helpers_match_flet_payload_shape
    path = Ruflet.path(
      elements: [
        Ruflet.path_arc(x: 1, y: 2, width: 3, height: 4, start_angle: 5, sweep_angle: 6),
        Ruflet.path_arc_to(x: 7, y: 8, radius: 9, rotation: 10, large_arc: true, clockwise: false),
        Ruflet.path_oval(x: 11, y: 12, width: 13, height: 14),
        Ruflet.path_rect(x: 15, y: 16, width: 17, height: 18, border_radius: 2),
        Ruflet.path_quadratic_to(cp1x: 19, cp1y: 20, x: 21, y: 22, w: 23),
        Ruflet.path_cubic_to(cp1x: 24, cp1y: 25, cp2x: 26, cp2y: 27, x: 28, y: 29),
        Ruflet.path_sub_path(elements: [Ruflet.path_line_to(30, 31)], x: 32, y: 33)
      ],
      paint: Ruflet.paint(color: "#112233")
    )

    assert_equal(
      [
        { "_type" => "Arc", "x" => 1, "y" => 2, "width" => 3, "height" => 4, "start_angle" => 5, "sweep_angle" => 6 },
        { "_type" => "ArcTo", "x" => 7, "y" => 8, "radius" => 9, "rotation" => 10, "large_arc" => true, "clockwise" => false },
        { "_type" => "Oval", "x" => 11, "y" => 12, "width" => 13, "height" => 14 },
        { "_type" => "Rect", "x" => 15, "y" => 16, "width" => 17, "height" => 18, "border_radius" => 2 },
        { "_type" => "QuadraticTo", "cp1x" => 19, "cp1y" => 20, "x" => 21, "y" => 22, "w" => 23 },
        { "_type" => "CubicTo", "cp1x" => 24, "cp1y" => 25, "cp2x" => 26, "cp2y" => 27, "x" => 28, "y" => 29 },
        { "_type" => "SubPath", "elements" => [{ "_type" => "LineTo", "x" => 30, "y" => 31 }], "x" => 32, "y" => 33 }
      ],
      path.to_patch.fetch("elements")
    )
  end

  def test_canvas_capture_methods_invoke_flet_method_names
    calls = []
    page = Object.new
    page.define_singleton_method(:invoke) do |control, method_name, args: nil, timeout: 10, on_result: nil|
      calls << [control, method_name, args, timeout, on_result]
    end

    canvas = Ruflet.canvas(width: 100, height: 100)
    canvas.runtime_page = page
    callback = ->(_result) {}

    canvas.capture(pixel_ratio: 2, timeout: 7, on_result: callback)
    canvas.get_capture(timeout: 8, on_result: callback)
    canvas.clear_capture(timeout: 9, on_result: callback)

    assert_equal(
      [
        [canvas, "capture", { "pixel_ratio" => 2 }, 7, callback],
        [canvas, "get_capture", nil, 8, callback],
        [canvas, "clear_capture", nil, 9, callback]
      ],
      calls
    )
  end
end
