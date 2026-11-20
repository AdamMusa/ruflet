# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/method_contracts/service"

# One test per service method: what it sends the client and that the reply
# reaches the caller. See test/support/method_contract.rb.
class ServiceMethodContractTest < Minitest::Test
  MethodContract.define_tests(self, Ruflet::UI::Services::RufletServices::CLASS_MAP.keys)
end
