# frozen_string_literal: true

require_relative "test_helper"

class ChildrenPropAliasTest < Minitest::Test
  def test_widget_builder_accepts_children_prop
    first = Ruflet.text(value: "first")
    second = Ruflet.text(value: "second")

    column = Ruflet.column(children: [first, second])

    assert_equal [first, second], column.children
  end

  def test_dsl_app_control_accepts_children_prop
    app = Ruflet::DSL::App.new(host: "0.0.0.0", port: 8550)
    first = app.text(value: "first")
    second = app.text(value: "second")

    column = app.column(children: [first, second])

    assert_equal [first, second], column.children
  end
end
