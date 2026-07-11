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

  def test_page_accepts_python_flet_style_chrome_assignments
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    app_bar = Ruflet.app_bar(title: Ruflet.text("Gallery"))
    fab = Ruflet.fab(icon: "add")
    navigation_bar = Ruflet.navigation_bar(destinations: [])

    page.appbar = app_bar
    page.floating_action_button = fab
    page.navigation_bar = navigation_bar
    page.add(Ruflet.text("Hello world"))

    assert_same app_bar, page.appbar
    assert_same fab, page.floating_action_button
    assert_same navigation_bar, page.navigation_bar

    view = patch_value(sent.last[1]["patch"], "views").first
    assert_equal "AppBar", view["appbar"]["_c"]
    assert_equal "FloatingActionButton", view["floating_action_button"]["_c"]
    assert_equal "NavigationBar", view["navigation_bar"]["_c"]
    refute view.key?("app_bar")
    refute view.key?("fab")
  end

  def test_page_add_rejects_old_keyword_chrome_arguments
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    error = assert_raises(ArgumentError) do
      page.add(Ruflet.text("Body"), appbar: Ruflet.app_bar(title: Ruflet.text("Home")))
    end

    assert_match(/accepts only controls/, error.message)
  end

  def test_page_controls_insert_remove_remove_at_and_clean_match_flet_shape
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    one = Ruflet.text("One")
    two = Ruflet.text("Two")
    three = Ruflet.text("Three")

    page.add(one)
    assert_equal [one], page.controls
    assert_equal ["One"], view_control_values(sent.last)

    page.insert(1, two, three)
    assert_equal [one, two, three], page.controls
    assert_equal ["One", "Two", "Three"], view_control_values(sent.last)

    page.remove(two)
    assert_equal [one, three], page.controls
    assert_equal ["One", "Three"], view_control_values(sent.last)

    page.remove_at(0)
    assert_equal [three], page.controls
    assert_equal ["Three"], view_control_values(sent.last)

    page.clean
    assert_equal [], page.controls
    assert_equal [], view_control_values(sent.last)
  end

  def test_page_controls_writer_replaces_root_controls
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.controls = [Ruflet.text("One"), Ruflet.text("Two")]

    assert_equal ["One", "Two"], page.controls.map { |control| control.props["value"] }
    assert_equal ["One", "Two"], view_control_values(sent.last)
  end

  def test_page_exposes_python_flet_view_properties
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    values = {
      auto_scroll: true,
      browser_context_menu: false,
      decoration: { bgcolor: "#FFFFFF" },
      floating_action_button_location: "center_float",
      foreground_decoration: { border_radius: 4 },
      padding: 12,
      spacing: 8
    }

    values.each { |name, value| page.public_send("#{name}=", value) }
    page.add(Ruflet.text("Body"))

    view = patch_value(sent.last[1]["patch"], "views").first
    values.each do |name, value|
      expected = value.is_a?(Hash) ? value.transform_keys(&:to_s) : value
      assert_equal expected, view[name.to_s]
      assert_equal value, page.public_send(name)
    end
  end

  def test_page_scroll_to_invokes_the_root_view_method
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    call_id = page.scroll_to(offset: 100, duration: 500, curve: "ease_in", timeout: 3)

    assert_match(/\Acall_/, call_id)
    action, payload = sent.last
    assert_equal Ruflet::Protocol::ACTIONS[:invoke_control_method], action
    assert_equal 1, payload["control_id"]
    assert_equal "scroll_to", payload["name"]
    assert_equal(
      {
        "offset" => 100,
        "delta" => nil,
        "scroll_key" => nil,
        "duration" => 500,
        "curve" => "ease_in"
      },
      payload["args"]
    )
    assert_equal 3, payload["timeout"]
  end

  def test_page_overlay_matches_python_flet_list_property
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    first = Ruflet.text("Overlay")
    second = Ruflet.text("Later")

    page.overlay = [first]
    page.add(Ruflet.text("Body"))
    assert_equal [first], page.overlay
    assert_equal ["Overlay"], overlay_control_values(sent.last)

    page.overlay = [first, second]
    assert_equal [first, second], page.overlay
    assert_equal ["Overlay", "Later"], overlay_control_values(sent.last)
  end

  def test_page_get_control_and_schedule_update_match_python_flet
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    control = Ruflet.text("Body", id: "body")
    page.add(control)

    assert_same control, page.get_control(control.wire_id)
    assert_same control, page.get_control("body")
    assert_same page, page.schedule_update
    assert_equal Ruflet::Protocol::ACTIONS[:patch_control], sent.last[0]
  end

  private

  def patch_value(patch, key)
    op = patch.find { |candidate| candidate[2] == key }
    op && op[3]
  end

  def view_control_values(sent_message)
    patch_value(sent_message[1]["patch"], "views").first.fetch("controls").map { |control| control["value"] }
  end

  def overlay_control_values(sent_message)
    patch = sent_message[1]["patch"]
    controls = patch_value(patch, "_overlay")&.fetch("controls")
    controls ||= patch.find { |op| op[2] == "controls" }&.fetch(3)
    controls.map { |control| control["value"] }
  end
end
