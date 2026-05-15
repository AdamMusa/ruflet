# frozen_string_literal: true

require_relative "test_helper"

class RufletPageCompatibilityTest < Minitest::Test
  def test_page_serializes_flet_page_props_as_page_patch_ops
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.set_view_props(
      title: "Demo",
      theme: { color_scheme_seed: "#ABCDEF" },
      dark_theme: { color_scheme_seed: "#000000" },
      theme_mode: "dark",
      fonts: { "Inter" => "/fonts/inter.ttf" },
      rtl: true,
      show_semantics_debugger: true,
      bgcolor: "#123456"
    )
    page.add(Ruflet.text("hello"))

    patch = sent.last[1]["patch"]

    assert_equal "Demo", patch_value(patch, "title")
    assert_equal({ "color_scheme_seed" => "#ABCDEF" }, patch_value(patch, "theme"))
    assert_equal({ "color_scheme_seed" => "#000000" }, patch_value(patch, "dark_theme"))
    assert_equal "dark", patch_value(patch, "theme_mode")
    assert_equal({ "Inter" => "/fonts/inter.ttf" }, patch_value(patch, "fonts"))
    assert_equal true, patch_value(patch, "rtl")
    assert_equal true, patch_value(patch, "show_semantics_debugger")

    view = patch_value(patch, "views").first
    assert_equal "#123456", view["bgcolor"]
    refute view.key?("theme")
    refute view.key?("dark_theme")
    refute view.key?("theme_mode")
    refute view.key?("fonts")
    refute view.key?("show_semantics_debugger")
  end

  def test_page_dispatches_route_change_and_updates_route_from_client_event
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    routes = []
    page.on_route_change = ->(event) { routes << event.value }

    page.dispatch_event(target: 1, name: "route_change", data: { "route" => "/store" })

    assert_equal "/store", page.route
    assert_equal ["/store"], routes
  end

  private

  def patch_value(patch, key)
    op = patch.find { |candidate| candidate[2] == key }
    op && op[3]
  end
end
