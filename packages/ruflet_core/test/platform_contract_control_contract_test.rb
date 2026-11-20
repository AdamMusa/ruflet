# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/control_contracts/platform"

# One wire-type, props and events test per platform contract spec (the
# controls whose Material or Cupertino look the client picks); see
# test/support/control_contract.rb for what each asserts.
class PlatformContractControlContractTest < Minitest::Test
  ControlContract.define_tests(self, "platform")
end
