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

    # The renderers read "destinations" (material_navigation_rail.dart,
    # cupertino_navigation_controls.dart). Before #135 the block's
    # destinations went to "controls", and the rail was drawn without them.
    assert_equal "navigationrail", rail.type
    assert_equal 2, rail.props["destinations"].length
    assert_equal %w[NavigationRailDestination NavigationRailDestination], rail.to_patch["destinations"].map { |d| d["_c"] }
    assert_empty rail.children
  end
end
