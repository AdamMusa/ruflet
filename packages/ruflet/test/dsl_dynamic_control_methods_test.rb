# frozen_string_literal: true

require_relative "test_helper"

class RufletDslDynamicControlMethodsTest < Minitest::Test
  def test_unknown_snake_case_helper_raises_no_method_error
    app = Ruflet::DSL.app
    assert_raises(NoMethodError) { app.auto_complete(suggestions: []) }
  end

  def test_unknown_helper_with_block_raises_no_method_error
    app = Ruflet::DSL.app
    assert_raises(NoMethodError) do
      app.navigation_rail do
        text(value: "item")
      end
    end
  end
end
