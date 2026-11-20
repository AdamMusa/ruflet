# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/control_contracts/extension"

# One wire-type, props and events test per extension control Ruflet ships;
# see test/support/control_contract.rb for what each asserts.
class ExtensionControlContractTest < Minitest::Test
  ControlContract.define_tests(self, "extension")
end
