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
end
