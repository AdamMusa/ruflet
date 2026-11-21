# frozen_string_literal: true

require_relative "test_helper"

class RufletProtocolCompatibilityTest < Minitest::Test
  def test_action_codes_match_ruflet_wire_protocol
    assert_equal 1, Ruflet::Protocol::ACTIONS[:register_client]
    assert_equal 2, Ruflet::Protocol::ACTIONS[:patch_control]
    assert_equal 3, Ruflet::Protocol::ACTIONS[:control_event]
    assert_equal 4, Ruflet::Protocol::ACTIONS[:update_control]
    assert_equal 5, Ruflet::Protocol::ACTIONS[:invoke_control_method]
    assert_equal 6, Ruflet::Protocol::ACTIONS[:session_crashed]
    assert_equal 7, Ruflet::Protocol::ACTIONS[:python_output]
  end

  def test_successful_register_response_matches_ruflet_wire_protocol
    assert_equal(
      { "session_id" => "session-1", "page_patch" => {}, "error" => "" },
      Ruflet::Protocol.register_response(session_id: "session-1")
    )
  end

  # The standalone server passed the client's invoke reply through as is,
  # while ConnectionProtocol (ruflet_rails) normalized it, so a reply spelled
  # callId/value reached its on_result under Rails, but Ruflet::Server
  # ignored it and on_result only got (nil, "execution expired") once the
  # call's timeout passed. No shipped client sends that spelling (they send
  # call_id/result/error). This test pins the fix on Ruflet::Server;
  # ProtocolActionContractTest checks that both receivers agree.
  def test_standalone_server_accepts_a_callId_and_value_invoke_reply
    replies = []
    target = nil
    server = Ruflet::Server.new(port: 0) { |page| page.add(target = Ruflet.text("x")) }
    ws = Struct.new(:sent) do
      def session_key = object_id
      def closed? = false
      def send_binary(bytes) = sent << bytes
    end.new([])
    server.instance_variable_get(:@connections)[ws.session_key] = ws
    deliver = ->(action, payload) { server.send(:handle_message, ws, Ruflet::WireCodec.pack([action, payload])) }
    deliver.call(Ruflet::Protocol::ACTIONS[:register_client], { "session_id" => "s1", "page" => { "route" => "/" } })
    page = server.instance_variable_get(:@sessions)[ws.session_key]

    call_id = page.invoke(target, "focus", on_result: ->(result, error) { replies << [result, error] })
    deliver.call(Ruflet::Protocol::ACTIONS[:invoke_control_method], { "callId" => call_id, "value" => 42 })

    assert_equal [[42, nil]], replies
  end
end
