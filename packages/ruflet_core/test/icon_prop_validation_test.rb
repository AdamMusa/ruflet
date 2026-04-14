# frozen_string_literal: true

require_relative "test_helper"

class RufletIconPropValidationTest < Minitest::Test
  def test_icon_control_requires_ruflet_icon_data
    app = Ruflet::DSL.app

    error = assert_raises(ArgumentError) { app.icon(icon: "add") }

    assert_includes error.message, "Ruflet::MaterialIcons"
  end

  def test_icon_button_requires_ruflet_icon_data
    app = Ruflet::DSL.app

    error = assert_raises(ArgumentError) { app.icon_button(icon: :add) }

    assert_includes error.message, "Ruflet::MaterialIcons"
  end

  def test_selected_icon_requires_ruflet_icon_data
    app = Ruflet::DSL.app

    error = assert_raises(ArgumentError) { app.navigation_bar_destination(icon: Ruflet::MaterialIcons::HOME, selected_icon: "settings") }

    assert_includes error.message, "Ruflet::MaterialIcons"
  end

  def test_material_icon_data_is_accepted
    app = Ruflet::DSL.app

    control = app.icon(icon: Ruflet::MaterialIcons::ADD)

    assert_equal Ruflet::MaterialIcons::ADD.value, control.props["icon"]
  end

  def test_page_updates_require_ruflet_icon_data
    page = Ruflet::Page.new

    error = assert_raises(ArgumentError) { page.update(nil, icon: "add") }

    assert_includes error.message, "Ruflet::MaterialIcons"
  end
end
