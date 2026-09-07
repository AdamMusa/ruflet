# frozen_string_literal: true

require_relative "test_helper"

class RufletConnectionProtocolTest < Minitest::Test
  class Host
    include Ruflet::ConnectionProtocol
  end

  def test_shared_receiver_accepts_python_output_without_closing_the_connection
    message = Ruflet::WireCodec.pack([
      Ruflet::Protocol::ACTIONS[:python_output],
      { "message" => "renderer diagnostic", "error" => false }
    ])

    assert_nil Host.new.handle_message(Object.new, message)
  end

  def test_shared_receiver_still_rejects_unknown_actions
    message = Ruflet::WireCodec.pack([999, {}])

    error = assert_raises(RuntimeError) { Host.new.handle_message(Object.new, message) }
    assert_equal "Unknown action: 999", error.message
  end
end
