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

  def test_page_exposes_client_reported_properties_as_readers
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: {
        "route" => "/",
        "width" => 1280,
        "height" => 800,
        "platform" => "macos",
        "platform_brightness" => "light",
        "web" => true,
        "pwa" => false,
        "wasm" => false,
        "media" => { "padding" => {} }
      },
      sender: ->(_action, _payload) {}
    )

    assert_equal 1280, page.width
    assert_equal 800, page.height
    assert_equal "macos", page.platform
    assert_equal "light", page.platform_brightness
    assert_equal true, page.web
    assert_equal false, page.pwa
    assert_equal false, page.wasm
    assert_equal({ "padding" => {} }, page.media)
  end

  def test_page_client_reported_readers_default_to_nil_without_client_data
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    assert_nil page.width
    assert_nil page.height
    assert_nil page.platform
  end

  def test_page_dispatches_route_change_and_updates_route_from_client_event
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    routes = []
    page.on_route_change = ->(event) { routes << [event.class, event.value] }

    page.dispatch_event(target: 1, name: "route_change", data: { "route" => "/store" })

    assert_equal "/store", page.route
    assert_equal [[Ruflet::Event, "/store"]], routes
  end

  def test_page_drawer_and_end_drawer_serialize_on_root_view_like_flet
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    drawer = Ruflet.navigation_drawer([
      Ruflet.navigation_drawer_destination(icon: "home", label: "Home")
    ])
    end_drawer = Ruflet.navigation_drawer([
      Ruflet.navigation_drawer_destination(icon: "search", label: "Search")
    ])

    page.drawer = drawer
    page.end_drawer = end_drawer
    page.add(Ruflet.text("body"))

    view = patch_value(sent.last[1]["patch"], "views").first
    assert_equal drawer, page.drawer
    assert_equal end_drawer, page.end_drawer
    assert_equal "NavigationDrawer", view["drawer"]["_c"]
    assert_equal "NavigationDrawer", view["end_drawer"]["_c"]
  end

  def test_page_drawer_methods_invoke_current_view_like_flet
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.drawer = Ruflet.navigation_drawer([
      Ruflet.navigation_drawer_destination(icon: "home", label: "Home")
    ])
    page.end_drawer = Ruflet.navigation_drawer([
      Ruflet.navigation_drawer_destination(icon: "search", label: "Search")
    ])
    page.add(Ruflet.text("body"))

    page.show_drawer
    page.close_drawer
    page.show_end_drawer
    page.close_end_drawer

    invoke_messages = sent.select { |action, _payload| action == Ruflet::Protocol::ACTIONS[:invoke_control_method] }
    assert_equal %w[show_drawer close_drawer show_end_drawer close_end_drawer], invoke_messages.map { |_action, payload| payload["name"] }
    assert_equal [20, 20, 20, 20], invoke_messages.map { |_action, payload| payload["control_id"] }
  end

  def test_page_show_drawer_requires_drawer_like_flet
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    assert_raises(ArgumentError) { page.show_drawer }
    assert_raises(ArgumentError) { page.show_end_drawer }
  end

  private

  def patch_value(patch, key)
    op = patch.find { |candidate| candidate[2] == key }
    op && op[3]
  end
end
