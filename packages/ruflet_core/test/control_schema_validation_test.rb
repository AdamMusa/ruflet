# frozen_string_literal: true

require_relative "test_helper"

class ControlSchemaValidationTest < Minitest::Test
  def test_unknown_property_raises_for_known_control
    error = assert_raises(ArgumentError) do
      Ruflet::Control.new(type: :textfield, not_a_real_prop: true)
    end

    assert_includes error.message, "Unknown attribute `not_a_real_prop`"
    assert_includes error.message, "textfield"
  end

  def test_unknown_event_raises_for_known_control
    error = assert_raises(ArgumentError) do
      Ruflet::Control.new(type: :textfield, on_not_real_event: ->(_e) {})
    end

    assert_includes error.message, "Unknown event `on_not_real_event`"
    assert_includes error.message, "textfield"
  end

  def test_file_picker_control_class_is_available
    klass = Ruflet::UI::ControlFactory::CLASS_MAP["file_picker"]
    refute_nil klass
    params = klass.instance_method(:initialize).parameters
    keys = params.select { |kind, _| kind == :key || kind == :keyreq }.map(&:last)
    assert_includes keys, :data
  end

  def test_python_common_attributes_are_supported_by_every_control_factory
    control = Ruflet.control(
      :text,
      value: "Body",
      flip: { horizontal: true },
      transform: { m00: 1 },
      ref: Object.new
    )

    assert_equal({ "horizontal" => true }, control.props["flip"])
    assert_equal({ "m00" => 1 }, control.props["transform"])
    refute control.props.key?("ref")
  end

  def test_python_common_attributes_are_supported_with_children
    child = Ruflet.text("Child")
    parent = Ruflet.column(
      controls: [child],
      flip: { vertical: true },
      transform: { m11: 1 }
    )

    assert_equal [child], parent.children
    assert_equal({ "vertical" => true }, parent.props["flip"])
    assert_equal({ "m11" => 1 }, parent.props["transform"])
  end

  def test_python_control_specific_attributes_are_supported
    observed = []
    text = Ruflet.text(
      "Body",
      align: "center",
      animate_opacity: true,
      width: 120,
      on_animation_end: ->(event) { observed << event }
    )
    image = Ruflet.image(
      src: "image.png",
      fit: "contain",
      animate_size: true,
      height: 80,
      on_size_change: ->(event) { observed << event }
    )

    assert_equal "center", text.props["align"]
    assert_equal true, text.props["animate_opacity"]
    assert_equal 120, text.props["width"]
    assert text.has_handler?("animation_end")
    assert_equal "contain", image.props["fit"]
    assert_equal true, image.props["animate_size"]
    assert_equal 80, image.props["height"]
    assert image.has_handler?("size_change")
    assert_empty observed
  end
end
