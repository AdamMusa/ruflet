# frozen_string_literal: true

require_relative "test_helper"

class ProtocolCompatibilityTest < Minitest::Test
  def test_action_codes_match_flet_message_action_values
    assert_equal 1, Ruflet::Protocol::ACTIONS.fetch(:register_client)
    assert_equal 2, Ruflet::Protocol::ACTIONS.fetch(:patch_control)
    assert_equal 3, Ruflet::Protocol::ACTIONS.fetch(:control_event)
    assert_equal 4, Ruflet::Protocol::ACTIONS.fetch(:update_control)
    assert_equal 5, Ruflet::Protocol::ACTIONS.fetch(:invoke_control_method)
    assert_equal 6, Ruflet::Protocol::ACTIONS.fetch(:session_crashed)
    assert_equal 7, Ruflet::Protocol::ACTIONS.fetch(:python_output)
  end

  def test_pack_message_accepts_symbol_action_names
    assert_equal [2, { "id" => 1 }], Ruflet::Protocol.pack_message(action: :patch_control, payload: { "id" => 1 })
  end

  def test_flet_protocol_body_normalizers
    assert_equal(
      { "id" => 42, "patch" => [[0], [0, 0, "value", "hello"]] },
      Ruflet::Protocol.normalize_patch_control_payload("id" => 42, "patch" => [[0], [0, 0, "value", "hello"]])
    )

    assert_equal(
      { "control_id" => 7, "call_id" => "call_1", "name" => "focus", "args" => nil, "timeout" => 10 },
      Ruflet::Protocol.normalize_invoke_method_payload("control_id" => 7, "call_id" => "call_1", "name" => "focus")
    )

    assert_equal(
      { "control_id" => 7, "call_id" => "call_1", "result" => true, "error" => nil },
      Ruflet::Protocol.normalize_invoke_method_result_payload("control_id" => 7, "call_id" => "call_1", "result" => true)
    )

    assert_equal(
      { "text" => "hello\n", "is_stderr" => false },
      Ruflet::Protocol.normalize_python_output_payload("text" => "hello\n")
    )

    assert_equal(
      { "message" => "boom" },
      Ruflet::Protocol.normalize_session_crashed_payload("message" => "boom")
    )
  end

  def test_register_response_keeps_flet_page_patch_key
    assert_equal(
      { "session_id" => "abc", "page_patch" => { "id" => 1 }, "error" => nil },
      Ruflet::Protocol.register_response(session_id: "abc", page_patch: { "id" => 1 })
    )
  end
end
