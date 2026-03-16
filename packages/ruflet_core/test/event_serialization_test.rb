# frozen_string_literal: true

require_relative "test_helper"

class EventSerializationTest < Minitest::Test
  def test_generated_flet_event_props_are_merged
    assert_equal "focus", Ruflet::UI::ControlRegistry::EVENT_PROPS[:on_focus]
    assert_equal "blur", Ruflet::UI::ControlRegistry::EVENT_PROPS[:on_blur]
    assert_equal "select", Ruflet::UI::ControlRegistry::EVENT_PROPS[:on_select]
  end

  def test_control_serializes_new_event_handler_flags
    control = Ruflet::Control.new(type: :textfield, on_focus: ->(_e) {})
    patch = control.to_patch

    assert_equal true, patch["on_focus"]
    assert control.has_handler?("focus")
  end

  def test_page_dispatches_new_event_handlers
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    events = []
    field = Ruflet.text_field(on_focus: ->(_e) { events << :focus })
    page.add(field)

    page.dispatch_event(target: field.wire_id, name: "focus", data: nil)

    assert_equal [:focus], events
  end
end
