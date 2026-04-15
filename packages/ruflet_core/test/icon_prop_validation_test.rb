# frozen_string_literal: true

require_relative "test_helper"

class RufletIconPropValidationTest < Minitest::Test
  def test_icon_control_accepts_icon_name_string
    app = Ruflet::DSL.app

    control = app.icon(icon: "add")

    assert_equal 65604, control.props["icon"]
  end

  def test_icon_button_accepts_symbol_as_icon_name
    app = Ruflet::DSL.app

    control = app.icon_button(icon: :add)

    assert_equal 65604, control.props["icon"]
  end

  def test_selected_icon_accepts_icon_name_string
    app = Ruflet::DSL.app

    control = app.navigation_bar_destination(icon: "home", selected_icon: "settings")

    assert_equal Ruflet::MaterialIconLookup.codepoint_for("home"), control.props["icon"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("settings"), control.props["selected_icon"]
  end

  def test_material_icon_constant_is_a_string
    app = Ruflet::DSL.app

    control = app.icon(icon: Ruflet::MaterialIcons::ADD)

    assert_equal 65604, control.props["icon"]
  end

  def test_page_updates_accept_icon_name_string
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    control = Ruflet.icon(icon: "home")
    page.add(control)
    page.update(control, icon: "add")

    patch = sent.last[1]["patch"].find { |op| op[2] == "icon" }
    assert_equal 65604, patch[3]
  end
end
