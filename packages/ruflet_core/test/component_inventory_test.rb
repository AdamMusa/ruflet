# frozen_string_literal: true

require_relative "test_helper"
require_relative "conformance/component_inventory"

class RufletComponentInventoryTest < Minitest::Test
  def test_all_python_flet_controls_are_implemented_or_classified
    inventory = RufletFletComponentInventory.inventory

    assert_equal [], inventory[:unclassified_missing]
  end
end
