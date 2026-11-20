# frozen_string_literal: true

require_relative "test_helper"

# Default arguments must reach the wire in shapes the Flutter renderer reads
# (AdamMusa/ruflet#94). The renderer reads an alignment as {x, y}, padding as
# left/top/right/bottom (or a number) and a border radius as per-corner keys
# (or a number). A default alignment "center" made it throw, and an
# {"all" => n} padding or radius was read as zero.
class RufletDefaultValueWireShapesTest < Minitest::Test
  CENTER = { "x" => 0.0, "y" => 0.0 }.freeze

  def patch_for(control)
    control.wire_id = 1
    control.to_patch
  end

  def test_icon_buttons_default_to_a_center_vector_and_per_side_padding
    {
      "FilledIconButton" => Ruflet.filled_icon_button(icon: "add"),
      "FilledTonalIconButton" => Ruflet.filled_tonal_icon_button(icon: "add"),
      "OutlinedIconButton" => Ruflet.outlined_icon_button(icon: "add")
    }.each do |wire, control|
      patch = patch_for(control)

      assert_equal wire, patch["_c"]
      assert_equal CENTER, patch["alignment"], wire
      assert_equal({ "left" => 8, "top" => 8, "right" => 8, "bottom" => 8 }, patch["padding"], wire)
    end
  end

  def test_cupertino_buttons_default_to_a_center_vector_and_per_corner_radius
    {
      "Button" => Ruflet.cupertino_button(content: Ruflet.text("Tap")),
      "FilledButton" => Ruflet.cupertino_filled_button(content: Ruflet.text("Tap")),
      "FilledTonalButton" => Ruflet.cupertino_tinted_button(content: Ruflet.text("Tap"))
    }.each do |wire, control|
      patch = patch_for(control)

      assert_equal wire, patch["_c"]
      assert_equal CENTER, patch["alignment"], wire
      assert_equal(
        { "top_left" => 8.0, "top_right" => 8.0, "bottom_left" => 8.0, "bottom_right" => 8.0 },
        patch["border_radius"],
        wire
      )
    end
  end

  def test_cupertino_timer_picker_defaults_to_a_center_vector
    patch = patch_for(Ruflet.cupertino_timer_picker)

    assert_equal "TimerPicker", patch["_c"]
    assert_equal CENTER, patch["alignment"]
  end

  def test_cupertino_text_field_defaults_to_per_side_padding
    patch = patch_for(Ruflet.cupertino_text_field)

    assert_equal "TextField", patch["_c"]
    assert_equal({ "left" => 7, "top" => 7, "right" => 7, "bottom" => 7 }, patch["padding"])
  end

  def test_explicit_values_are_still_sent_unchanged
    assert_equal "center", patch_for(Ruflet.cupertino_timer_picker(alignment: "center"))["alignment"]
    assert_equal({ "x" => 1, "y" => -1 }, patch_for(Ruflet.filled_icon_button(icon: "add", alignment: { x: 1, y: -1 }))["alignment"])
    assert_equal 4, patch_for(Ruflet.outlined_icon_button(icon: "add", padding: 4))["padding"]
    assert_equal({ "all" => 3 }, patch_for(Ruflet.filled_icon_button(icon: "add", padding: { "all" => 3 }))["padding"])
    assert_equal 12, patch_for(Ruflet.cupertino_button(border_radius: 12))["border_radius"]
    assert_equal 2, patch_for(Ruflet.cupertino_text_field(padding: 2))["padding"]
  end

  # No control built with default arguments sends an {"all" => n} map, which
  # the renderer reads as zero padding or square corners.
  def test_no_control_default_sends_an_all_shorthand_map
    factory = Ruflet::UI::ControlFactory
    built = 0
    offenders = []

    factory::CLASS_MAP.each_key do |name|
      control = begin
        factory.build(name)
      rescue ArgumentError
        next
      end
      built += 1
      control.wire_id = 1
      each_hash_path(control.to_patch) do |hash, path|
        offenders << "#{name}#{path}" if hash.key?("all")
      end
    end

    assert_operator built, :>, 300, "expected most controls to build with no arguments"
    assert_empty offenders, "defaults sent as {\"all\" => n}: #{offenders.join(', ')}"
  end

  private

  def each_hash_path(value, path = "", &block)
    case value
    when Hash
      yield value, path
      value.each { |key, child| each_hash_path(child, "#{path}.#{key}", &block) }
    when Array
      value.each_with_index { |child, index| each_hash_path(child, "#{path}[#{index}]", &block) }
    end
  end
end
