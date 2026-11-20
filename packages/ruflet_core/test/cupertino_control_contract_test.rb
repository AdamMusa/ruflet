# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/control_contracts/cupertino"

# One wire-type, props and events test per cupertino control spec; see
# test/support/control_contract.rb for what each asserts.
class CupertinoControlContractTest < Minitest::Test
  ControlContract.define_tests(self, "cupertino")
end
