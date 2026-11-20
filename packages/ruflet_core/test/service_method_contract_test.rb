# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/method_contracts/service"

# One test per service method: what it sends the client and that the reply
# reaches the caller. See test/support/method_contract.rb.
class ServiceMethodContractTest < Minitest::Test
  MethodContract.define_tests(self, Ruflet::UI::Services::RufletServices::CLASS_MAP.keys)

  # The spec passes a configuration; without one there are no args.
  def test_geolocator_get_current_position_without_a_configuration_sends_no_args
    sent = []
    _page, geolocator = method_contract_control(MethodContract.specs.fetch(%w[geolocator get_current_position]), sent)

    geolocator.get_current_position

    assert_nil invoke_payloads(sent).last["args"]
  end
end
