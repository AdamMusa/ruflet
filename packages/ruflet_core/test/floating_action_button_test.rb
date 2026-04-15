# frozen_string_literal: true

require_relative "test_helper"

class RufletFloatingActionButtonTest < Minitest::Test
  def test_fab_with_icon_control_keeps_icon_prop
    app = Ruflet::DSL.app

    fab = app.fab(icon: app.icon(icon: Ruflet::MaterialIcons::ADD))

    assert_kind_of Ruflet::Control, fab.props["icon"]
    assert_nil fab.props["content"]
  end

  def test_fab_with_string_content_keeps_text_content
    app = Ruflet::DSL.app

    fab = app.fab("Create", on_click: ->(_event) {})

    assert_equal "Create", fab.props["content"]
  end

  def test_fab_with_keyword_string_content_keeps_text_content
    app = Ruflet::DSL.app

    fab = app.fab(content: "Create")

    assert_equal "Create", fab.props["content"]
  end

  def test_fab_with_string_icon_prop_is_accepted
    app = Ruflet::DSL.app

    fab = app.fab(icon: "add")

    assert_equal 65604, fab.props["icon"]
  end

  def test_fab_with_icon_ignores_blank_keyword_content
    app = Ruflet::DSL.app

    fab = app.fab(icon: "add", content: "")

    assert_equal 65604, fab.props["icon"]
    refute fab.props.key?("content")
  end

  def test_fab_with_icon_and_text_content_keeps_both
    app = Ruflet::DSL.app

    fab = app.fab(icon: "add", content: "Create")

    assert_equal 65604, fab.props["icon"]
    assert_equal "Create", fab.props["content"]
  end

  def test_fab_with_material_icon_keeps_icon_prop
    app = Ruflet::DSL.app

    fab = app.fab(icon: Ruflet::MaterialIcons::ADD)

    assert_equal 65604, fab.props["icon"]
    assert_nil fab.props["content"]
  end
end
