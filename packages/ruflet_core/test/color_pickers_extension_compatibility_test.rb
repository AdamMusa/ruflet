# frozen_string_literal: true

require_relative "test_helper"

class ColorPickersExtensionCompatibilityTest < Minitest::Test
  def test_every_flet_color_picker_has_a_typed_ruby_helper
    controls = [
      Ruflet.block_picker(color: "#FF0000", available_colors: ["#FF0000"]),
      Ruflet.color_picker(color: "#00FF00", hsv_color: { alpha: 1, hue: 120, saturation: 1, value: 1 }),
      Ruflet.hue_ring_picker(color: "#0000FF", enable_alpha: true),
      Ruflet.material_picker(color: "#FF0000", enable_label: true),
      Ruflet.multiple_choice_block_picker(colors: ["#FF0000", "#00FF00"]),
      Ruflet.slide_picker(color: "#123456", color_model: :rgb)
    ]

    assert_equal %w[BlockPicker ColorPicker HueRingPicker MaterialPicker MultipleChoiceBlockPicker SlidePicker],
                 controls.map { |control| control.to_patch["_c"] }
    assert_equal "rgb", controls.last.to_patch["color_model"]
  end

  def test_color_picker_events_are_registered
    picker = Ruflet.color_picker(on_color_change: ->(_event) {}, on_history_change: ->(_event) {})

    assert picker.has_handler?(:color_change)
    assert picker.has_handler?(:history_change)
  end
end
