# frozen_string_literal: true

require "minitest/autorun"
require "json"

require_relative "../helpers"

# Regression: Flutter/Flet's GestureDetector emits flat local coordinates as
# lx/ly (global as gx/gy). Minesweeper derives the tapped cell from these, so
# extract_pos must read that format — not just nested {localPosition:{x,y}}.
class GesturePositionTest < Minitest::Test
  include Showcase::Helpers

  Event = Struct.new(:data)

  def test_reads_flat_local_lx_ly_from_flet
    pos = extract_pos(Event.new({ "kind" => "touch", "lx" => 54.0, "ly" => 108.0, "gx" => 200, "gy" => 300 }))
    assert_equal({ x: 54.0, y: 108.0 }, pos)
  end

  def test_reads_lx_ly_from_json_string_payload
    pos = extract_pos(Event.new('{"lx":54,"ly":108}'))
    assert_equal({ x: 54.0, y: 108.0 }, pos)
  end

  def test_falls_back_to_global_when_local_absent
    pos = extract_pos(Event.new({ "gx" => 5, "gy" => 6 }))
    assert_equal({ x: 5.0, y: 6.0 }, pos)
  end

  def test_still_supports_legacy_nested_local_position
    pos = extract_pos(Event.new({ "localPosition" => { "x" => 10, "y" => 20 } }))
    assert_equal({ x: 10.0, y: 20.0 }, pos)
  end

  def test_returns_nil_without_position_data
    assert_nil extract_pos(Event.new(nil))
    assert_nil extract_pos(Event.new({ "kind" => "touch" }))
    assert_nil extract_pos(Event.new("not json"))
  end
end
