# frozen_string_literal: true

require_relative "test_helper"

class CanvasDrawingCompatibilityTest < Minitest::Test
  def test_canvas_serializes_shapes_and_path_elements
    drawing_paint = Ruflet.paint(color: "#ff6b6b", stroke_width: 3, style: "stroke")
    canvas = Ruflet.canvas(
      [
        Ruflet.line(x1: 1, y1: 2, x2: 3, y2: 4, paint: drawing_paint),
        Ruflet.circle(x: 12, y: 18, radius: 7, paint: drawing_paint),
        Ruflet.rect(x: 20, y: 24, width: 60, height: 30, paint: drawing_paint),
        Ruflet.path(
          elements: [Ruflet.path_move_to(4, 4), Ruflet.path_line_to(14, 10), Ruflet.path_close],
          paint: drawing_paint
        )
      ],
      width: 300,
      height: 200
    )

    patch = canvas.to_patch
    assert_equal "Canvas", patch["_c"]
    assert_equal %w[Line Circle Rect Path], patch.fetch("shapes").map { |shape| shape["_c"] }
    assert_equal(
      [
        { "_type" => "MoveTo", "x" => 4, "y" => 4 },
        { "_type" => "LineTo", "x" => 14, "y" => 10 },
        { "_type" => "Close" }
      ],
      patch.fetch("shapes").last.fetch("elements")
    )
  end

  def test_all_path_element_helpers_match_wire_payloads
    path = Ruflet.path(
      elements: [
        Ruflet.path_arc(x: 1, y: 2),
        Ruflet.path_arc_to(x: 3, y: 4),
        Ruflet.path_oval(x: 5, y: 6),
        Ruflet.path_rect(x: 7, y: 8),
        Ruflet.path_quadratic_to(x: 9, y: 10),
        Ruflet.path_cubic_to(x: 11, y: 12),
        Ruflet.path_sub_path(elements: [Ruflet.path_line_to(13, 14)])
      ]
    )

    assert_equal(
      %w[Arc ArcTo Oval Rect QuadraticTo CubicTo SubPath],
      path.to_patch.fetch("elements").map { |element| element["_type"] }
    )
  end

  def test_extension_helpers_preserve_positional_payload_slots
    rive = Ruflet.rive("https://example.test/animation.riv", fit: "contain")
    editor = Ruflet.code_editor("puts :ok", language: "ruby")
    map = Ruflet.map([Ruflet.tile_layer(url_template: "https://tiles.test/{z}/{x}/{y}")])

    assert_equal "https://example.test/animation.riv", rive.to_patch["src"]
    assert_equal "puts :ok", editor.to_patch["value"]
    assert_equal "CodeEditor", editor.to_patch["_c"]
    assert_equal "https://tiles.test/{z}/{x}/{y}", map.to_patch.fetch("layers").first["url_template"]
  end
end
