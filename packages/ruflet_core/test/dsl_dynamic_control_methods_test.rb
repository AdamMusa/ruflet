# frozen_string_literal: true

require_relative "test_helper"

class RufletDslDynamicControlMethodsTest < Minitest::Test
  def test_unknown_snake_case_helper_raises_no_method_error
    app = Ruflet::DSL.app
    assert_raises(NoMethodError) { app.not_a_real_control(suggestions: []) }
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
