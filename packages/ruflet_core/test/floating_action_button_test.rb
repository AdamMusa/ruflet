# frozen_string_literal: true

require_relative "test_helper"

class RufletFloatingActionButtonTest < Minitest::Test
  def test_fab_with_icon_control_moves_icon_into_content
    app = Ruflet::DSL.app

    fab = app.fab(icon: app.icon(icon: Ruflet::MaterialIcons::ADD))

    assert_nil fab.props["icon"]
    assert_instance_of Ruflet::Control, fab.props["content"]
    assert_equal "icon", fab.props["content"].type
  end

  def test_fab_with_material_icon_content_wraps_icon_control
    app = Ruflet::DSL.app

    fab = app.fab(Ruflet::MaterialIcons::ADD, on_click: ->(_event) {})

    assert_instance_of Ruflet::Control, fab.props["content"]
    assert_equal "icon", fab.props["content"].type
    assert_equal Ruflet::MaterialIcons::ADD, fab.props["content"].props["icon"]
  end

  def test_fab_with_string_content_raises_clear_error
    app = Ruflet::DSL.app

    error = assert_raises(ArgumentError) { app.fab("+", on_click: ->(_event) {}) }
    assert_includes error.message, "Ruflet::MaterialIcons"
  end

  def test_fab_with_string_icon_prop_raises_clear_error
    app = Ruflet::DSL.app

    error = assert_raises(ArgumentError) { app.fab(icon: "+") }
    assert_includes error.message, "Ruflet::MaterialIcons"
  end

  def test_fab_with_icon_codepoint_keeps_icon_prop
    app = Ruflet::DSL.app

    fab = app.fab(icon: Ruflet::MaterialIcons::ADD)

    refute_nil fab.props["icon"]
    assert_nil fab.props["content"]
  end
end
