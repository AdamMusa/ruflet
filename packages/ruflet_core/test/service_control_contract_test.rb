# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/control_contracts/service"

# One wire-type, props and events test per service control spec; see
# test/support/control_contract.rb for what each asserts.
class ServiceControlContractTest < Minitest::Test
  ControlContract.define_tests(self, "service")
end
