# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/control_contracts/shared"

# One wire-type, props and events test per shared control spec; see
# test/support/control_contract.rb for what each asserts.
class SharedControlContractTest < Minitest::Test
  ControlContract.define_tests(self, "shared")
end
