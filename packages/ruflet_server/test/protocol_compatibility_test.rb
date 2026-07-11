# frozen_string_literal: true

require_relative "test_helper"

class RufletProtocolCompatibilityTest < Minitest::Test
  def test_action_codes_match_python_flet
    assert_equal 1, Ruflet::Protocol::ACTIONS[:register_client]
    assert_equal 2, Ruflet::Protocol::ACTIONS[:patch_control]
    assert_equal 3, Ruflet::Protocol::ACTIONS[:control_event]
    assert_equal 4, Ruflet::Protocol::ACTIONS[:update_control]
    assert_equal 5, Ruflet::Protocol::ACTIONS[:invoke_control_method]
    assert_equal 6, Ruflet::Protocol::ACTIONS[:session_crashed]
    assert_equal 7, Ruflet::Protocol::ACTIONS[:python_output]
  end

  def test_successful_register_response_matches_python_flet
    assert_equal(
      { "session_id" => "session-1", "page_patch" => {}, "error" => "" },
      Ruflet::Protocol.register_response(session_id: "session-1")
    )
  end
end
