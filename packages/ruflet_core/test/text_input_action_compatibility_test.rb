# frozen_string_literal: true

require_relative "test_helper"

class RufletTextInputActionCompatibilityTest < Minitest::Test
  def test_text_field_serializes_text_input_action
    email = Ruflet.text_field(label: "Email", keyboard_type: "email", text_input_action: "next")
    password = Ruflet.text_field(label: "Password", password: true, text_input_action: :done)

    assert_equal "TextField", email.to_patch["_c"]
    assert_equal "next", email.to_patch["text_input_action"]
    assert_equal "done", password.to_patch["text_input_action"]
  end

  def test_text_input_action_is_omitted_by_default
    field = Ruflet.text_field(label: "Name")

    refute field.to_patch.key?("text_input_action")
  end

  def test_text_input_action_passes_snake_and_camel_case_through
    snake = Ruflet.text_field(text_input_action: "continue_action")
    camel = Ruflet.text_field(text_input_action: "emergencyCall")

    assert_equal "continue_action", snake.to_patch["text_input_action"]
    assert_equal "emergencyCall", camel.to_patch["text_input_action"]
  end

  def test_every_text_field_schema_accepts_text_input_action
    [
      Ruflet::UI::Controls::RufletComponents::TextFieldControl,
      Ruflet::UI::Controls::RufletComponents::CupertinoTextFieldControl,
      Ruflet::UI::PlatformControlContracts::Components::TextFieldControl
    ].each do |klass|
      assert_includes klass::KEYWORDS, :text_input_action, klass.name
    end

    material = Ruflet::UI::Controls::RufletComponents::TextFieldControl.new(text_input_action: "send")
    cupertino = Ruflet.cupertino_text_field(text_input_action: "search")

    assert_equal "send", material.to_patch["text_input_action"]
    assert_equal "TextField", cupertino.to_patch["_c"]
    assert_equal "search", cupertino.to_patch["text_input_action"]
  end

  def test_multiline_text_field_keeps_submit_handler_with_text_input_action
    submitted = []
    field = Ruflet.text_field(
      multiline: true,
      text_input_action: "done",
      on_submit: ->(event) { submitted << event.data }
    )

    assert_equal true, field.to_patch["on_submit"]
    assert_equal "done", field.to_patch["text_input_action"]
    assert field.has_handler?(:submit)
  end

  def test_unknown_keyword_is_still_rejected
    assert_raises(ArgumentError) { Ruflet.text_field(text_input_actions: "next") }
  end
end
