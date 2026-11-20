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
end
