# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/method_contracts/control"

# One test per control method (shipped extensions included): what it sends
# the client and that the reply reaches the caller. See
# test/support/method_contract.rb.
class ControlMethodContractTest < Minitest::Test
  MethodContract.define_tests(
    self,
    MethodContract.specs.values.map(&:type).uniq - Ruflet::UI::Services::RufletServices::CLASS_MAP.keys
  )

  # The spec covers a named edge (bottom_right -> bottomRight); one the
  # table does not name is sent as its String.
  def test_window_start_resizing_sends_an_unknown_edge_as_a_string
    sent = []
    _page, window = method_contract_control(MethodContract.specs.fetch(%w[window start_resizing]), sent)

    window.start_resizing(:middle)

    assert_equal({ "edge" => "middle" }, invoke_payloads(sent).last["args"])
  end
end
