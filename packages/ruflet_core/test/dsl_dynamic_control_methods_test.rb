# frozen_string_literal: true

require_relative "test_helper"

class RufletDslDynamicControlMethodsTest < Minitest::Test
  def test_unknown_snake_case_helper_builds_generic_extension_control
    app = Ruflet::DSL.app
    control = app.custom_extension_control(value: "ready")

    assert_equal "custom_extension_control", control.type
    assert_equal "CustomExtensionControl", control.to_patch["_c"]
  end

  def test_navigation_rail_helper_with_block_is_supported
    app = Ruflet::DSL.app

    rail = app.navigation_rail do
      navigation_rail_destination(icon: "home")
      navigation_rail_destination(icon: "search")
    end

    assert_equal "navigationrail", rail.type
    assert_equal 2, rail.children.length
  end
end
