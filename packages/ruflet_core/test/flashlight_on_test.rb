# frozen_string_literal: true

require_relative "test_helper"

# Flashlight#on is two methods: Flet's "turn the light on" (no event name)
# and Ruflet::Control#on(event_name, &block), which it used to hide.
class FlashlightOnTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" },
                             sender: ->(action, payload) { @sent << [action, payload] })
    @flashlight = Ruflet.flashlight
    @page.add_service(@flashlight)
    @sent.clear
  end

  def invokes
    @sent.select { |action, _| action == Ruflet::Protocol::ACTIONS[:invoke_control_method] }.map(&:last)
  end

  def test_on_without_an_event_name_turns_the_light_on
    replies = []
    call_id = @flashlight.on(timeout: 3, on_result: ->(result, error) { replies << [result, error] })

    assert_equal [["on", nil, 3]], invokes.map { |payload| [payload["name"], payload["args"], payload["timeout"]] }
    assert_equal invokes.first["call_id"], call_id
    @page.handle_invoke_method_result("call_id" => call_id, "result" => true, "error" => nil)
    assert_equal [[true, nil]], replies
  end

  def test_on_with_only_a_block_still_turns_the_light_on
    ran = []
    @flashlight.on { ran << :block }

    assert_equal ["on"], invokes.map { |payload| payload["name"] }
    assert_empty ran
  end

  def test_on_with_an_event_name_registers_the_handler
    seen = []
    result = @flashlight.on(:error) { |e| seen << e.data }

    assert_same @flashlight, result
    assert_empty invokes, "registering a handler turns nothing on"
    assert_equal true, @flashlight.props["on_error"]

    @page.dispatch_event(target: @flashlight.wire_id, name: "error", data: { "message" => "no torch" })
    assert_equal [{ "message" => "no torch" }], seen
  end

  # Without a block it is Control#on on any control: it subscribes the
  # event (on_error, one patch) and runs nothing when the event arrives.
  def test_on_with_an_event_name_and_no_block_is_control_on
    button = Ruflet.button("b")
    @page.add(button)
    @sent.clear

    assert_same button, button.on(:click)
    button_messages = @sent.map(&:first)
    @sent.clear

    assert_same @flashlight, @flashlight.on(:error)
    assert_equal true, @flashlight.props["on_error"]
    assert_empty invokes, "subscribing turns nothing on"
    assert_equal button_messages, @sent.map(&:first)
    assert_equal 1, @sent.size
    refute @flashlight.has_handler?(:error)
  end

  def test_on_with_an_on_spelled_event_name_registers_the_handler
    seen = []
    @flashlight.on("on_error") { |e| seen << e.name }

    @page.dispatch_event(target: @flashlight.wire_id, name: "error", data: nil)
    assert_equal ["error"], seen
  end

  def test_on_with_an_unknown_event_name_raises_as_control_on_does
    assert_raises(ArgumentError) { @flashlight.on(:bogus) {} }
    assert_raises(ArgumentError) { @flashlight.on(:error, :again) {} }
    assert_raises(ArgumentError) { @flashlight.on(:error, on_result: ->(*) {}) {} }
    assert_empty invokes
  end
end
