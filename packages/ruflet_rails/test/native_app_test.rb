# frozen_string_literal: true

require_relative "test_helper"

# Managed native shell. A tiny WebView-side adapter reads ERB-rendered
# data-ruflet-* declarations and Ruby turns them into Ruflet controls.
class RufletNativeAppTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(session_id: "na", client_details: {},
                             sender: ->(a, p) { @sent << [a, p] })
  end

  def find(node, type)
    case node
    when Ruflet::Control
      return node if node.type == type

      node.props.each_value { |v| (f = find(v, type)) and return f }
      node.children.each { |c| (f = find(c, type)) and return f }
      nil
    when Array
      node.each { |v| (f = find(v, type)) and return f }
      nil
    end
  end

  def stack
    @page.views
  end

  def controls_of(control)
    Array(control.children.empty? ? control.props["controls"] : control.children)
  end

  def body_of(view = stack.last)
    controls_of(view).first
  end

  def top_webview
    find(stack.last, "webview")
  end

  # Simulate the HTML adapter posting a console message from the top screen.
  def post(message, webview: top_webview)
    @page.dispatch_event(target: webview.wire_id, name: "console_message",
                         data: { "message" => message, "severity_level" => "log" })
  end

  def start(**opts)
    Ruflet::Rails.native_app(@page, start_url: "https://myapp.com", **opts)
  end

  def wait_for_async_invokes
    sleep 0.08
  end

  # --- HTML adapter -------------------------------------------------------

  def test_html_adapter_reads_explicit_ruflet_attributes
    js = Ruflet::Rails::NativeApp.html_adapter_js
    assert_includes js, "addEventListener"
    assert_includes js, "preventDefault"
    assert_includes js, "data-ruflet-screen"
    assert_includes js, "data-ruflet-action"
    refute_includes js, 'report("visit"'
    refute_includes js, "turbo:before-visit"
    refute_includes js, "configuredScreenLinks"
    refute_includes js, "window.RufletNative"
    refute_includes js, 'report("title"'
    refute_includes js, "ruflet:title"
    assert_includes js, '"ruflet:"' # message channel prefix
  end

  # --- out-of-the-box navigation -----------------------------------------

  def test_starts_with_one_webview_screen
    start
    assert_equal 1, stack.length
    assert_equal "https://myapp.com", top_webview.props["url"]
    assert_equal "get", top_webview.props["method"]
    assert_equal true, top_webview.props["enable_javascript"], "JS on for the HTML adapter + WebAuthn/passkeys"
    assert_equal "view", stack.first.type
    assert_nil find(stack.first, "appbar"), "no native chrome by default; the web page supplies its own header"
  end

  def test_webview_screen_has_a_native_loading_shimmer
    start
    body = body_of(stack.first)
    assert_equal "stack", body.type
    assert_same top_webview, find(body, "webview")

    loading = find(body, "shimmer")
    refute_nil loading
    assert_equal true, controls_of(body).last.props["visible"]
  end

  def test_loading_shimmer_is_only_inside_the_webview_body
    start(title: "Demo")
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "house", "url" => "/" },
      { "label" => "Inbox", "icon" => "mail", "url" => "/inbox" }
    ] })}))

    body = body_of(stack.first)
    appbar = stack.first.props["appbar"]
    navbar = stack.first.props["navigation_bar"]

    assert_equal "stack", body.type
    refute_nil find(body, "shimmer"), "body owns the loading shimmer"
    refute_nil appbar, "native appbar stays outside the loading layer"
    refute_nil navbar, "native bottom navigation stays outside the loading layer"
    assert_nil find(appbar, "shimmer")
    assert_nil find(navbar, "shimmer")
  end

  def test_page_ended_hides_the_loading_shimmer
    start
    loading = controls_of(body_of(stack.first)).last
    assert_equal true, loading.props["visible"]

    @page.dispatch_event(target: top_webview.wire_id, name: "page_ended", data: "https://myapp.com")
    assert_equal false, loading.props["visible"]
  end

  def test_page_ended_before_loading_mount_still_hides_the_shimmer
    start
    loading = controls_of(body_of(stack.first)).last
    loading.wire_id = nil
    assert_equal true, loading.props["visible"]

    @page.dispatch_event(target: top_webview.wire_id, name: "page_ended", data: "https://myapp.com")

    assert_equal false, loading.props["visible"]
  end

  def test_flush_reconciles_hidden_loading_after_the_control_mounts
    start
    loading = controls_of(body_of(stack.first)).last
    loading.wire_id = nil
    @page.dispatch_event(target: top_webview.wire_id, name: "page_ended", data: "https://myapp.com")
    assert_equal false, loading.props["visible"]

    loading.wire_id = 42
    @sent.clear
    action("push", "/settings")

    assert @sent.any? { |_action, payload| payload.to_s.include?('"visible", false') || payload.inspect.include?('"visible"=>false') },
           "a hidden loading overlay must stay hidden once the client has mounted it"
  end

  def test_web_resource_error_hides_the_loading_shimmer
    start
    loading = controls_of(body_of(stack.first)).last
    assert_equal true, loading.props["visible"]

    @page.dispatch_event(target: top_webview.wire_id, name: "web_resource_error", data: "server unavailable")
    assert_equal false, loading.props["visible"]
  end

  def test_loading_can_be_a_simple_text_overlay
    start(loading: "Loading page")
    body = body_of(stack.first)

    assert_equal "stack", body.type
    loading = controls_of(body).last
    assert_equal "container", loading.type
    assert_equal "Loading page", find(loading, "text").props["value"]
  end

  def test_loading_can_be_disabled
    start(loading: false)

    assert_same top_webview, body_of(stack.first)
    assert_nil find(stack.first, "shimmer")
  end

  def test_plain_ruflet_page_is_not_wrapped_in_a_webview_screen
    plain = Ruflet::Page.new(session_id: "plain", client_details: {}, sender: ->(_a, _p) {})
    plain.add(text("Normal Ruflet"))
    root_controls = plain.instance_variable_get(:@root_controls)

    assert_empty plain.views
    assert_nil find(root_controls, "webview"), "only NativeApp creates the WebView shell"
    assert find(root_controls, "text"), "ordinary Ruflet controls still render normally"
  end

  def test_appbar_is_rendered_when_a_title_is_given
    start(title: "My App")
    refute_nil find(stack.first, "appbar"), "passing a title opts into native chrome"
  end

  def test_page_started_switches_javascript_mode_to_unrestricted
    start
    @sent.clear
    @page.dispatch_event(target: top_webview.wire_id, name: "page_started", data: "https://myapp.com")

    enabled = @sent.any? do |_action, payload|
      payload.to_s.include?("set_javascript_mode") && payload.to_s.include?("unrestricted")
    end
    assert enabled, "page_started must enable JS (the mobile client ignores the enable_javascript prop)"
  end

  def test_plain_link_visit_messages_are_ignored
    start
    post("ruflet:visit:https://myapp.com/about")
    assert_equal 1, stack.length, "native navigation must be declared with data-ruflet-*"
  end

  def test_back_pops_the_pushed_screen
    start
    action("push", "https://myapp.com/about")
    assert_equal 1, stack.length
    assert_equal "https://myapp.com/about", top_webview.props["url"]

    @page.dispatch_event(target: 1, name: "view_pop", data: nil)
    assert_equal 1, stack.length
    assert_equal "https://myapp.com", top_webview.props["url"]
  end

  # --- dynamic appbar -----------------------------------------------------

  def test_actions_lambda_is_resolved_into_the_appbar
    start(actions: -> { [icon_button("search")] })
    appbar = find(stack.first, "appbar")
    assert_equal 1, Array(appbar.props["actions"]).length
    assert_equal "iconbutton", appbar.props["actions"].first.type
  end

  def test_unmatched_messages_are_ignored
    start
    post("some random console output")
    post("ruflet:visit:not a url ::::")
    assert_equal 1, stack.length
  end

  # --- explicit data-ruflet navigation -----------------------------------

  def action(action, url = nil, component: "navigation", **payload)
    post("ruflet:action:#{JSON.generate(payload.merge({ "component" => component, "action" => action, "url" => url }).compact)}")
  end

  def test_action_push_pushes_a_webview_screen
    start
    action("push", "https://myapp.com/a")
    assert_equal 1, stack.length
    assert_equal "https://myapp.com/a", top_webview.props["url"]
  end

  def test_action_push_without_declared_chrome_still_keeps_shimmer_in_body
    start
    action("push", "https://myapp.com/inbox")

    appbar = find(stack.last, "appbar")
    body = body_of(stack.last)

    refute_nil appbar, "pushed native screens mount appbar before the WebView body loads"
    assert_equal "Inbox", find(appbar, "text").props["value"]
    refute_nil appbar.props["leading"], "pushed native screens get an immediate back/close leading"
    assert_equal "stack", body.type
    refute_nil find(body, "shimmer"), "only the WebView body shows loading"
    assert_nil find(appbar, "shimmer"), "native appbar never becomes part of the loading skeleton"
  end

  def test_action_push_resolves_relative_urls_against_the_current_screen
    start
    action("push", "/inbox")

    assert_equal 1, stack.length
    assert_equal "https://myapp.com/inbox", top_webview.props["url"]
  end

  def test_action_push_can_add_native_screen_chrome_with_close_leading
    start
    action("push", "https://myapp.com/signup/new", "title" => "Sign up", "leading" => { "icon" => "close", "action" => "back" })

    appbar = find(stack.last, "appbar")
    refute_nil appbar
    assert_equal "Sign up", find(appbar, "text").props["value"]
    leading = appbar.props["leading"]
    assert_equal "iconbutton", leading.type
    refute_nil leading.props["icon"]

    leading.emit("click", Ruflet::Event.new(name: "click", target: leading.wire_id, raw_data: nil, page: @page, control: leading))
    assert_equal 1, stack.length, "the close leading button pops the native screen"
    assert_equal "https://myapp.com", top_webview.props["url"]
  end

  def test_action_back_pops_the_top_screen
    start
    action("push", "https://myapp.com/a")
    action("back")
    assert_equal 1, stack.length
  end

  def test_action_root_resets_the_stack_to_a_single_root
    start
    action("push", "https://myapp.com/a")
    action("push", "https://myapp.com/b")
    assert_equal 1, stack.length
    assert_equal "https://myapp.com/b", top_webview.props["url"]

    action("root", "https://myapp.com/home")
    assert_equal 1, stack.length, "root collapses the stack to one root screen"
    assert_equal "https://myapp.com/home", top_webview.props["url"]
    assert_equal "/", stack.first.props["route"], "the surviving screen is the root view"
  end

  # Rails native navigation is a normal Ruflet shell: push is Ruby-side history
  # plus a body/appbar patch, not a client Navigator stack.
  def test_pushed_webview_screens_reuse_the_single_shell_route
    start
    action("push", "https://myapp.com/a")
    action("push", "https://myapp.com/b")
    routes = stack.map { |view| view.props["route"] }
    assert_equal ["/"], routes
    assert_equal "https://myapp.com/b", top_webview.props["url"]
  end

  def test_action_replace_swaps_the_top_screen_without_growing_the_stack
    start
    action("push", "https://myapp.com/a")
    assert_equal 1, stack.length

    action("replace", "https://myapp.com/b")
    assert_equal 1, stack.length, "replace swaps inside the stable shell"
    assert_equal "https://myapp.com/b", top_webview.props["url"]
  end

  def test_action_replace_from_root_keeps_a_single_root_screen
    start
    action("replace", "https://myapp.com/home")
    assert_equal 1, stack.length
    assert_equal "/", stack.first.props["route"]
    assert_equal "https://myapp.com/home", top_webview.props["url"]
  end

  def test_action_sheet_opens_a_bottom_sheet
    start
    action("sheet", "https://myapp.com/quick")
    assert_equal 1, stack.length, "an explicit sheet never pushes a screen"
    sheet = @page.instance_variable_get(:@bottom_sheet)
    refute_nil sheet
    assert_equal true, sheet.props["show_drag_handle"], "the sheet has a modal drag handle"
    assert_equal true, sheet.props["draggable"], "drag the handle down to dismiss"
    assert_nil sheet.props["fullscreen"], "the sheet is not fullscreen (that looks like a push)"
    assert_equal true, sheet.props["scrollable"], "scroll-controlled so it can grow tall"
    assert_equal "https://myapp.com/quick", find(sheet, "webview").props["url"]
  end

  def test_native_overlays_and_loading_accept_ruflet_props
    start(loading: {
      type: "text",
      text: "Loading body",
      container_props: { bgcolor: "#010203" },
      text_props: { color: "#ffffff", size: 18 }
    })
    loading = controls_of(body_of(stack.first)).last
    assert_equal "#010203", loading.props["bgcolor"]
    assert_equal "#ffffff", find(loading, "text").props["color"]
    assert_equal 18, find(loading, "text").props["size"]

    post(%(ruflet:action:#{JSON.generate({ "component" => "toast", "message" => "Saved", "bgcolor" => "#222222",
                                           "content_props" => { "color" => "#eeeeee" } })}))
    snackbar = @page.instance_variable_get(:@snack_bar)
    assert_equal "#222222", snackbar.props["bgcolor"]
    assert_equal "#eeeeee", find(snackbar, "text").props["color"]

    post(%(ruflet:action:#{JSON.generate({ "component" => "dialog", "title" => "Confirm", "content" => "Continue?",
                                           "bgcolor" => "#ffffff", "title_props" => { "color" => "#111111" } })}))
    dialog = @page.instance_variable_get(:@dialogs).last
    assert_equal "#ffffff", dialog.props["bgcolor"]
    assert_equal "#111111", dialog.props["title"].props["color"]

    post(%(ruflet:action:#{JSON.generate({ "component" => "sheet", "url" => "/quick", "bgcolor" => "#fafafa",
                                           "card_props" => { "bgcolor" => "#eeeeee" } })}))
    sheet = @page.instance_variable_get(:@bottom_sheet)
    assert_equal "#fafafa", sheet.props["bgcolor"]
    assert_equal "#eeeeee", sheet.props["content"].props["bgcolor"]
  end

  # --- HTML-promoted native chrome ---------------------------------------

  def test_appbar_message_promotes_a_native_appbar_with_leading_and_actions
    start # no title: full-bleed by default
    assert_nil find(stack.first, "appbar")
    action("push", "https://myapp.com/signup/new")
    assert_equal 1, stack.length
    view = stack.last
    webview = top_webview

    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Sign up", "leading" => { "icon" => "close", "action" => "back" }, "actions" => [{ "icon" => "search", "url" => "https://myapp.com/search", "action" => "push" }] })}))
    appbar = find(stack.last, "appbar")
    refute_nil appbar, "ruflet-appbar promotes a native AppBar"
    assert_same view, stack.last, "promoting appbar should patch the mounted view in place"
    assert_same webview, top_webview, "promoting appbar should not recreate the WebView"
    assert_equal "Sign up", find(appbar, "text").props["value"]
    refute_nil appbar.props["leading"].props["icon"]
    assert_equal 1, Array(appbar.props["actions"]).length
    assert_equal "iconbutton", appbar.props["actions"].first.type

    appbar.props["leading"].emit("click", Ruflet::Event.new(name: "click", target: appbar.props["leading"].wire_id, raw_data: nil, page: @page, control: appbar.props["leading"]))
    assert_equal 1, stack.length, "appbar leading back action pops the native auth screen"
  end

  def test_declared_appbar_title_replaces_the_initial_title
    start(title: "Ruflet Rails Demo")
    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Demo" })}))
    title = find(find(stack.first, "appbar"), "text")

    assert_equal "Demo", title.props["value"]
  end

  def test_native_chrome_payloads_customize_ruflet_controls
    start
    post(%(ruflet:appbar:#{JSON.generate({
      "title" => "Styled",
      "bgcolor" => "#101827",
      "color" => "#f8fafc",
      "center_title" => true,
      "title_props" => { "color" => "#ff00ff", "size" => 22 },
      "actions" => [{ "icon" => "settings", "url" => "/settings", "icon_color" => "#00ff00", "tooltip" => "Settings" }]
    })}))
    post(%(ruflet:bottomnav:#{JSON.generate({
      "bgcolor" => "#111111",
      "indicator_color" => "#222222",
      "items" => [
        { "label" => "Home", "icon" => "home", "url" => "/", "selected_icon" => "home_filled", "tooltip" => "Home" },
        { "label" => "Inbox", "icon" => "mail", "url" => "/inbox" }
      ]
    })}))
    post(%(ruflet:drawer:#{JSON.generate({
      "bgcolor" => "#ffffff",
      "width" => 320,
      "items" => [
        { "label" => "Home", "icon" => "home", "url" => "/", "selected_tile_color" => "#ddeeff", "title_props" => { "color" => "#123456" } }
      ]
    })}))

    appbar = find(stack.first, "appbar")
    assert_equal "#101827", appbar.props["bgcolor"]
    assert_equal "#f8fafc", appbar.props["color"]
    assert_equal true, appbar.props["center_title"]
    assert_equal "#ff00ff", find(appbar, "text").props["color"]
    assert_equal 22, find(appbar, "text").props["size"]
    assert_equal "#00ff00", appbar.props["actions"].first.props["icon_color"]

    navbar = find(stack.first, "navigationbar")
    assert_equal "#111111", navbar.props["bgcolor"]
    assert_equal "#222222", navbar.props["indicator_color"]
    assert_equal "Home", navbar.props["destinations"].first.props["tooltip"]

    drawer = stack.first.props["drawer"]
    assert_equal "#ffffff", drawer.props["bgcolor"]
    assert_equal 320, drawer.props["width"]
    first_tile = controls_of(drawer).first
    assert_equal "#ddeeff", first_tile.props["selected_tile_color"]
    assert_equal "#123456", find(first_tile, "text").props["color"]
  end

  def test_appbar_leading_can_open_the_native_drawer
    start
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/" }
    ] })}))
    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Demo", "leading" => { "icon" => "menu", "action" => "drawer" } })}))
    appbar = find(stack.first, "appbar")

    assert_nil appbar.props["leading"], "drawer leading should use Flutter's native implied AppBar drawer button"
    assert stack.first.props["drawer"], "the current native view owns a drawer for the implied leading"
  end

  def test_appbar_drawer_leading_waits_for_declared_drawer
    start
    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Demo", "leading" => { "icon" => "menu", "action" => "drawer" } })}))
    appbar = find(stack.first, "appbar")
    assert_nil appbar.props["leading"]
    assert_nil stack.first.props["drawer"]

    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/" }
    ] })}))
    assert stack.first.props["drawer"], "once the drawer arrives Flutter can show the implied AppBar drawer button"
  end

  def test_drawer_leading_opens_from_pushed_screen_and_after_back
    start
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/" },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))
    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Demo", "leading" => { "icon" => "menu", "action" => "drawer" } })}))

    action("push", "/settings", "title" => "Settings", "leading" => { "icon" => "menu", "action" => "drawer" })
    pushed_appbar = find(stack.last, "appbar")

    assert_nil pushed_appbar.props["leading"], "drawer leading is delegated to Flutter's implied AppBar drawer button"

    @page.dispatch_event(target: 1, name: "view_pop", data: nil)
    root_appbar = find(stack.last, "appbar")

    assert_nil root_appbar.props["leading"]
    assert stack.last.props["drawer"], "root drawer should still be attached after returning from a pushed settings screen"
  end

  # End-to-end with the demo's exact declared payload: the body is the real
  # WebView and the AppBar / drawer / bottom nav / rail are a normal Ruflet app
  # (real controls), all delivered over the protocol.
  def test_declared_payload_builds_a_normal_ruflet_chrome_over_the_webview_body
    start(title: "Demo")
    # What the HTML adapter reports from the home page's ruflet_appbar/drawer/bottom_nav/rail.
    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Demo", "leading" => { "icon" => "menu", "action" => "drawer" },
                                           "actions" => [{ "icon" => "settings", "url" => "/settings", "action" => "push",
                                                           "title" => "Settings", "leading" => { "icon" => "close", "action" => "back" } }] })}))
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/", "selected" => true },
      { "label" => "Inbox", "icon" => "mail", "url" => "/inbox", "action" => "root" },
      { "label" => "Profile", "icon" => "person", "url" => "/profile", "action" => "root" },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/", "selected" => true },
      { "label" => "Inbox", "icon" => "mail", "url" => "/inbox" },
      { "label" => "Profile", "icon" => "person", "url" => "/profile" }
    ] })}))
    post(%(ruflet:rail:#{JSON.generate({ "extended" => true, "breakpoint" => 720, "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/", "selected" => true },
      { "label" => "Inbox", "icon" => "mail", "url" => "/inbox" },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))

    # The body is the real WebView; the rest is real Ruflet UI.
    refute_nil find(stack.first, "webview"), "the body stays the real WebView"
    appbar = find(stack.first, "appbar")
    assert_equal "Demo", find(appbar, "text").props["value"]
    assert_nil appbar.props["leading"], "drawer leading uses Flutter's implied AppBar button"
    assert_equal 1, Array(appbar.props["actions"]).length, "the settings AppBar action is a real Ruflet button"
    assert_equal 4, Array(controls_of(stack.first.props["drawer"])).length
    assert_equal 3, Array(find(stack.first, "navigationbar").props["destinations"]).length
    assert_equal 3, Array(find(stack.first, "navigationrail").props["destinations"]).length
  end

  # The action's declared payload (title/leading for the body it opens) drives
  # the Ruflet shell — not a generic default.
  def test_appbar_action_payload_drives_the_pushed_screen_chrome
    start(title: "Demo")
    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Demo", "leading" => { "icon" => "menu", "action" => "drawer" },
                                           "actions" => [{ "icon" => "settings", "url" => "https://myapp.com/settings", "action" => "push",
                                                           "title" => "Settings", "leading" => { "icon" => "close", "action" => "back" } }] })}))
    settings_action = find(stack.first, "appbar").props["actions"].first
    settings_action.emit("click", Ruflet::Event.new(name: "click", target: settings_action.wire_id, raw_data: nil, page: @page, control: settings_action))

    assert_equal 1, stack.length, "the action navigates inside the stable shell"
    assert_equal "https://myapp.com/settings", top_webview.props["url"]
    pushed = find(stack.last, "appbar")
    assert_equal "Settings", find(pushed, "text").props["value"], "the declared title is honored"
    refute_nil pushed.props["leading"], "the declared close/back leading is honored, not a generic default"
  end

  # The desync scenario, end to end: every page re-reports the same chrome with
  # ITS OWN item marked selected. The chrome must pass through the page to ruflet
  # as PERSISTENT controls — re-reporting only re-points the selection, it never
  # rebuilds (and discards) the control. If it rebuilt, the drawer's open/close
  # state and the highlighted tab would drift out of sync.
  def test_chrome_passes_through_the_page_as_persistent_controls_without_desync
    start(title: "Demo")
    drawer_payload = lambda do |selected|
      { "items" => %w[/ /inbox /profile].each_with_index.map do |url, i|
        { "label" => url, "icon" => "home", "url" => url, "selected" => (i == selected) }
      end }
    end
    nav_payload = lambda do |selected|
      { "items" => %w[/ /inbox /profile].each_with_index.map do |url, i|
        { "label" => url, "icon" => "home", "url" => url, "selected" => (i == selected) }
      end }
    end

    # Home page reports its chrome (Home selected).
    post(%(ruflet:drawer:#{JSON.generate(drawer_payload.call(0))}))
    post(%(ruflet:bottomnav:#{JSON.generate(nav_payload.call(0))}))
    drawer = stack.first.props["drawer"]
    navbar = find(stack.first, "navigationbar")
    assert_equal 0, drawer.props["selected_index"]

    # Switch to the Inbox tab via the bottom nav.
    @page.dispatch_event(target: navbar.wire_id, name: "change", data: { "selected_index" => 1 })
    assert_equal "https://myapp.com/inbox", top_webview.props["url"]

    # The Inbox page loads and re-reports the SAME chrome, now with Inbox marked
    # selected. This is the moment that used to desync.
    post(%(ruflet:drawer:#{JSON.generate(drawer_payload.call(1))}))
    post(%(ruflet:bottomnav:#{JSON.generate(nav_payload.call(1))}))

    assert_same drawer, stack.first.props["drawer"], "the drawer is the same persistent control, not rebuilt"
    assert_same navbar, find(stack.first, "navigationbar"), "the bottom nav is the same persistent control, not rebuilt"
    assert_equal 1, drawer.props["selected_index"], "the drawer highlight followed the route, in sync"
    assert_equal [false, true, false], controls_of(drawer).map { |row| row.props["selected"] },
                 "the visible drawer rows follow the active route too"
    assert_equal 1, navbar.props["selected_index"], "the bottom nav highlight followed the route, in sync"
  end

  def test_duplicate_appbar_message_does_not_rebuild_the_webview_screen
    start
    payload = { "title" => "Sign up", "leading" => { "icon" => "close", "action" => "back" } }

    post("ruflet:appbar:#{JSON.generate(payload)}")
    view = stack.last
    webview = top_webview

    post("ruflet:appbar:#{JSON.generate(payload)}")
    assert_same view, stack.last, "same appbar payload should not recreate the view"
    assert_same webview, top_webview, "same appbar payload should not recreate the WebView"
  end

  def test_bottomnav_message_sets_the_root_navigation_bar
    start
    view = stack.first
    webview = top_webview
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "house", "url" => "https://myapp.com/" },
      { "label" => "Profile", "icon" => "person", "url" => "https://myapp.com/profile", "selected" => false }
    ] })}))
    navbar = find(stack.first, "navigationbar")
    refute_nil navbar, "ruflet-bottomnav builds a native NavigationBar"
    assert_same view, stack.first, "promoting bottomnav should patch the root view in place"
    assert_same webview, top_webview, "promoting bottomnav should not recreate the root WebView"
    assert_equal 2, Array(navbar.props["destinations"]).length
  end

  def test_bottomnav_selection_switches_to_the_destination_url
    start
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "house", "url" => "https://myapp.com/" },
      { "label" => "Profile", "icon" => "person", "url" => "https://myapp.com/profile" }
    ] })}))
    navbar = find(stack.first, "navigationbar")
    @page.dispatch_event(target: navbar.wire_id, name: "change", data: { "selected_index" => 1 })

    assert_equal 1, stack.length, "selecting a tab switches root, not pushes"
    assert_equal "https://myapp.com/profile", top_webview.props["url"]
  end

  def test_bottomnav_selection_to_current_url_does_not_reload_root
    start
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "house", "url" => "https://myapp.com", "selected" => true },
      { "label" => "Profile", "icon" => "person", "url" => "https://myapp.com/profile" }
    ] })}))
    view = stack.first
    webview = top_webview
    navbar = find(stack.first, "navigationbar")

    @page.dispatch_event(target: navbar.wire_id, name: "change", data: { "selected_index" => 0 })

    assert_same view, stack.first, "tapping the already-selected root tab should not rebuild the native view"
    assert_same webview, top_webview, "tapping Home on Home should not flash/reload the WebView body"
  end

  # Switching tabs must keep the native shell (AppBar + NavigationBar) mounted
  # and only reload the body — otherwise the chrome flashes on every tab. The
  # body is swapped via an in-place controls patch (a fresh WebView), never a
  # load_request invoke (which the client drops after a push/pop) and never a
  # full views resend (which re-mounts the shell).
  def test_tab_switch_reuses_the_shell_and_only_reloads_the_body
    start(title: "Demo")
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "house", "url" => "https://myapp.com/", "selected" => true },
      { "label" => "Inbox", "icon" => "mail", "url" => "https://myapp.com/inbox" }
    ] })}))
    view = stack.first
    webview = top_webview
    navbar = find(stack.first, "navigationbar")
    appbar = find(stack.first, "appbar")
    @sent.clear

    @page.dispatch_event(target: navbar.wire_id, name: "change", data: { "selected_index" => 1 })

    assert_equal 1, stack.length, "a tab switch stays a single root"
    assert_same view, stack.first, "the root view (shell) is reused, not rebuilt"
    assert_same navbar, find(stack.first, "navigationbar"), "the NavigationBar is not rebuilt on a tab switch"
    assert_same appbar, find(stack.first, "appbar"), "the AppBar is not rebuilt on a tab switch"
    refute_same webview, top_webview, "the body is a fresh WebView (so it mounts its own listeners)"
    assert_equal "https://myapp.com/inbox", top_webview.props["url"]
    assert_equal "Inbox", find(appbar, "text").props["value"],
                 "the AppBar shows the destination tab immediately, not the previous route"

    body_swap = @sent.find { |_action, payload| payload["id"] == view.wire_id && payload["patch"].to_s.include?("controls") }
    refute_nil body_swap, "the body is swapped via an in-place controls patch on the view"
    refute @sent.any? { |_action, payload| payload.to_s.include?("load_request") },
           "no load_request invoke (its client listener is lost after a push/pop)"
    refute @sent.any? { |_action, payload| payload["id"] == 1 && payload["patch"].to_s.include?("views") },
           "a tab switch must not re-send the whole views list (that re-mounts the shell)"
  end

  # Regression: the bottom nav stopped working after navigating via the drawer.
  # A drawer push + back re-sends the view stack, which on the client re-creates
  # the WebView control and drops its load_request invoke listener. Because the
  # tab switch now swaps the body with a control patch (not a load_request
  # invoke), it keeps working regardless of how many push/pops happened.
  def test_bottom_nav_works_after_a_push_and_pop
    start(title: "Demo")
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "house", "url" => "https://myapp.com/", "selected" => true },
      { "label" => "Inbox", "icon" => "mail", "url" => "https://myapp.com/inbox" }
    ] })}))
    view = stack.first
    navbar = find(stack.first, "navigationbar")

    # Simulate a drawer-style push then a back. The bottom nav remains the same
    # mounted Ruflet control; only the body/appbar are patched.
    action("push", "https://myapp.com/settings", "title" => "Settings", "leading" => { "icon" => "close", "action" => "back" })
    @page.dispatch_event(target: 1, name: "view_pop", data: nil)
    assert_equal 1, stack.length
    navbar_after_back = find(stack.first, "navigationbar")
    assert_same navbar, navbar_after_back,
                "back keeps the native bottom nav mounted with its callback intact"
    @sent.clear

    @page.dispatch_event(target: navbar_after_back.wire_id, name: "change", data: { "selected_index" => 1 })

    assert_equal "https://myapp.com/inbox", top_webview.props["url"],
                 "the bottom nav still navigates after a push/pop"
    refute @sent.any? { |_action, payload| payload.to_s.include?("load_request") },
           "navigation never relies on a load_request invoke"
    assert @sent.any? { |_action, payload| payload["id"] == view.wire_id && payload["patch"].to_s.include?("controls") },
           "the body is swapped with an in-place controls patch on the reused view"
  end

  def test_bottomnav_uses_declared_page_appbar_instead_of_tab_label
    start(title: "Demo")
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "house", "url" => "https://myapp.com/", "selected" => true },
      { "label" => "Inbox", "icon" => "mail", "url" => "https://myapp.com/inbox" }
    ] })}))
    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Demo", "leading" => { "icon" => "menu", "action" => "drawer" } })}))
    navbar = find(stack.first, "navigationbar")

    @page.dispatch_event(target: navbar.wire_id, name: "change", data: { "selected_index" => 1 })
    @sent.clear
    @page.dispatch_event(target: navbar.wire_id, name: "change", data: { "selected_index" => 0 })

    assert_equal "https://myapp.com/", top_webview.props["url"]
    assert_equal "Demo", find(find(stack.first, "appbar"), "text").props["value"]
    refute @sent.any? { |_action, payload| payload.to_s.include?('"value"=>"Home"') || payload.to_s.include?('"value", "Home"') },
           "Home tab should not temporarily replace the page-declared Demo appbar title"
  end

  # The drawer must track the route we're on, not the one we left.
  def test_tab_switch_syncs_the_drawer_selection_to_the_new_route
    start(title: "Demo")
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "house", "url" => "https://myapp.com/", "selected" => true },
      { "label" => "Inbox", "icon" => "mail", "url" => "https://myapp.com/inbox" }
    ] })}))
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "https://myapp.com/", "selected" => true },
      { "label" => "Inbox", "icon" => "mail", "url" => "https://myapp.com/inbox" }
    ] })}))
    drawer = stack.first.props["drawer"]
    navbar = find(stack.first, "navigationbar")
    assert_equal 0, drawer.props["selected_index"]

    @page.dispatch_event(target: navbar.wire_id, name: "change", data: { "selected_index" => 1 })

    assert_equal 1, drawer.props["selected_index"],
                 "after switching to Inbox the drawer highlights Inbox, not Home"
    assert_equal [false, true], controls_of(drawer).map { |row| row.props["selected"] },
                 "the visible drawer row selection follows the active route"
  end

  # Drawer links that point at tab destinations must behave as tab/root
  # navigation even if the HTML payload says push. Inbox/Profile should keep the
  # root shell: drawer leading, selected bottom nav item, no pushed close button.
  def test_drawer_navigation_to_bottomnav_destination_selects_tab_not_push
    start(title: "Demo")
    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Demo", "leading" => { "icon" => "menu", "action" => "drawer" } })}))
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "house", "url" => "https://myapp.com/", "selected" => true },
      { "label" => "Inbox", "icon" => "mail", "url" => "https://myapp.com/inbox" },
      { "label" => "Profile", "icon" => "person", "url" => "https://myapp.com/profile" }
    ] })}))
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "https://myapp.com/", "selected" => true },
      { "label" => "Inbox", "icon" => "mail", "url" => "https://myapp.com/inbox", "action" => "push" },
      { "label" => "Profile", "icon" => "person", "url" => "https://myapp.com/profile", "action" => "push" }
    ] })}))
    drawer = stack.first.props["drawer"]
    @sent.clear

    @page.dispatch_event(target: drawer.wire_id, name: "change", data: { "value" => 1 })

    assert @sent.any? { |_action, payload| payload.to_s.include?("close_drawer") },
           "drawer navigation closes the native drawer before switching tabs"
    assert_equal 1, stack.length, "tab destinations from the drawer reuse the root screen"
    assert_equal "https://myapp.com/inbox", top_webview.props["url"]
    assert_equal 1, find(stack.first, "navigationbar").props["selected_index"],
                 "the matching bottom-nav destination becomes active"
    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Inbox", "leading" => { "icon" => "close", "action" => "back" } })}))
    assert_nil find(stack.first, "appbar").props["leading"],
               "Inbox keeps Flutter's implied drawer leading, not a close button"

    @sent.clear
    @page.dispatch_event(target: drawer.wire_id, name: "change", data: { "value" => 2 })

    assert @sent.any? { |_action, payload| payload.to_s.include?("close_drawer") },
           "drawer navigation closes the native drawer for profile too"
    assert_equal 1, stack.length
    assert_equal "https://myapp.com/profile", top_webview.props["url"]
    assert_equal 2, find(stack.first, "navigationbar").props["selected_index"],
                 "Profile becomes the active bottom-nav destination"
    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Profile", "leading" => { "icon" => "close", "action" => "back" } })}))
    assert_nil find(stack.first, "appbar").props["leading"],
               "Profile keeps Flutter's implied drawer leading, not a close button"
  end

  # mode: root collapses any pushed screens but reuses the root shell (view +
  # AppBar + NavigationBar); only the body is swapped.
  def test_root_navigation_collapses_pushed_screens_but_reuses_root_shell
    start(title: "Demo")
    root_view = stack.first
    action("push", "https://myapp.com/a")
    assert_equal 1, stack.length

    action("root", "https://myapp.com/home")

    assert_equal 1, stack.length, "root collapses back to a single screen"
    assert_same root_view, stack.first, "the surviving screen is the original root view"
    assert_equal "https://myapp.com/home", top_webview.props["url"]
  end

  # Tapping a drawer item selects it when its route is the active body URL, just
  # like bottomnav does. A declared default remains only the fallback.
  def test_drawer_push_item_selects_matching_active_route
    start
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/", "selected" => true },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))
    drawer = stack.first.props["drawer"]
    drawer.props["selected_index"] = 1 # client highlights the tapped Settings

    @page.dispatch_event(target: drawer.wire_id, name: "change", data: { "value" => 1 })

    assert_equal 1, stack.length, "the push item navigates inside the stable shell"
    assert_equal "https://myapp.com/settings", top_webview.props["url"]
    assert_equal 1, drawer.props["selected_index"],
                 "the drawer highlights the item whose route matches the active body URL"
    assert_equal [false, true], controls_of(drawer).map { |row| row.props["selected"] },
                 "the matching drawer row is visibly selected"
  end

  # A push opened from the drawer keeps its own declared chrome (back button),
  # rather than being forced into a title-only AppBar by the tab title hint.
  def test_drawer_push_keeps_declared_back_button
    start
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/", "selected" => true },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))
    drawer = stack.first.props["drawer"]

    @page.dispatch_event(target: drawer.wire_id, name: "change", data: { "value" => 1 })
    # The pushed settings screen reports its own appbar with a close/back leading.
    post(%(ruflet:appbar:#{JSON.generate({ "title" => "Settings", "leading" => { "icon" => "close", "action" => "back" } })}))

    appbar = find(stack.last, "appbar")
    refute_nil appbar.props["leading"], "the pushed screen keeps its back/close button"
  end

  # A freshly pushed screen renders its AppBar immediately with the loading
  # shimmer confined to the body — the same shape as a root/tab load.
  def test_pushed_screen_renders_appbar_with_shimmer_only_in_body
    start
    action("push", "https://myapp.com/detail", "title" => "Detail", "leading" => { "icon" => "close", "action" => "back" })

    appbar = find(stack.last, "appbar")
    body = body_of(stack.last)

    refute_nil appbar, "the pushed screen's AppBar is rendered before the body loads"
    assert_equal "stack", body.type
    refute_nil find(body, "shimmer"), "the body owns the loading shimmer"
    assert_nil find(appbar, "shimmer"), "the shimmer never covers the AppBar"
    assert_equal true, controls_of(body).last.props["visible"], "the shimmer is visible while the body loads"
  end

  # After a back navigation the drawer must reflect the screen returned to, not
  # the destination tapped to leave it.
  def test_drawer_selection_resets_after_navigating_back
    start
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/", "selected" => true },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))
    drawer = stack.first.props["drawer"]

    # Select Settings: closes the drawer and pushes the settings screen. The
    # client marks Settings (index 1) selected on the drawer.
    @page.dispatch_event(target: drawer.wire_id, name: "change", data: { "value" => 1 })
    assert_equal 1, stack.length
    assert_equal "https://myapp.com/settings", top_webview.props["url"]
    drawer.props["selected_index"] = 1

    @page.dispatch_event(target: 1, name: "view_pop", data: nil)

    assert_equal 1, stack.length
    assert_equal "https://myapp.com", top_webview.props["url"]
    assert_equal 0, stack.first.props["drawer"].props["selected_index"],
                 "returning to the root resets the drawer selection to the current screen"
  end

  def test_drawer_stays_mounted_and_closes_after_native_back
    start
    root = stack.first
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/", "selected" => true },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))
    drawer = root.props["drawer"]
    action("push", "/settings", "title" => "Settings", "leading" => { "icon" => "close", "action" => "back" })
    @sent.clear

    @page.dispatch_event(target: 1, name: "view_pop", data: nil)

    assert_same drawer, root.props["drawer"],
                "returning from a native screen keeps the root drawer mounted"
    assert @sent.any? { |_action, payload| payload["control_id"] == root.wire_id && payload.to_s.include?("close_drawer") },
           "returning to root closes any drawer state left open underneath the pushed screen"
  end

  def test_bottomnav_selection_resolves_relative_urls_before_loading_webview
    start
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "house", "url" => "/" },
      { "label" => "Inbox", "icon" => "mail", "url" => "/inbox" }
    ] })}))
    navbar = find(stack.first, "navigationbar")
    @page.dispatch_event(target: navbar.wire_id, name: "change", data: { "selected_index" => 1 })

    assert_equal 1, stack.length
    assert_equal "https://myapp.com/inbox", top_webview.props["url"]
  end

  def test_pushed_screen_does_not_inherit_root_bottom_navigation
    start
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "house", "url" => "/" },
      { "label" => "Inbox", "icon" => "mail", "url" => "/inbox" }
    ] })}))

    action("push", "/settings", "title" => "Settings", "leading" => { "icon" => "close", "action" => "back" })

    assert_nil stack.last.props["navigation_bar"], "pushed native screens should not display the root tab bar"
    assert_nil stack.last.props["bottom_appbar"], "pushed native screens should not display root bottom app chrome"
  end

  def test_duplicate_bottomnav_message_does_not_rebuild_the_root_webview
    start
    payload = { "items" => [
      { "label" => "Home", "icon" => "house", "url" => "https://myapp.com/" },
      { "label" => "Profile", "icon" => "person", "url" => "https://myapp.com/profile" }
    ] }

    post("ruflet:bottomnav:#{JSON.generate(payload)}")
    view = stack.first
    webview = top_webview

    post("ruflet:bottomnav:#{JSON.generate(payload)}")
    assert_same view, stack.first, "same bottomnav payload should not recreate the root view"
    assert_same webview, top_webview, "same bottomnav payload should not recreate the root WebView"
  end

  def test_bottomnav_with_fewer_than_two_items_is_ignored
    start
    post(%(ruflet:bottomnav:#{JSON.generate({ "items" => [{ "label" => "Home", "icon" => "house", "url" => "/" }] })}))
    assert_nil find(stack.first, "navigationbar")
  end

  def test_drawer_message_sets_a_native_drawer_on_the_reporting_screen
    start
    view = stack.first
    webview = top_webview
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/", "selected" => true },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))

    drawer = find(stack.first.props["drawer"], "navigationdrawer")
    refute_nil drawer, "ruflet-drawer builds a native NavigationDrawer"
    assert_same view, stack.first, "promoting drawer should patch the mounted view in place so invokes stay attached"
    assert_same webview, top_webview, "promoting drawer should not recreate the WebView"
    assert_equal 2, Array(controls_of(drawer)).length
    assert_equal 0, drawer.props["selected_index"]
  end

  def test_drawer_selection_closes_drawer_and_navigates_with_item_mode
    start
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/" },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))
    drawer = stack.first.props["drawer"]
    @sent.clear

    @page.dispatch_event(target: drawer.wire_id, name: "change", data: { "value" => 1 })

    assert @sent.any? { |_action, payload| payload.to_s.include?("close_drawer") },
           "drawer selection closes the drawer before navigation"
    assert_equal 1, stack.length
    assert_equal "https://myapp.com/settings", top_webview.props["url"]
    assert @sent.any? { |_action, payload| payload["control_id"] == stack.last.wire_id && payload.to_s.include?("close_drawer") },
           "drawer selection closes the resulting native screen after navigation too"
  end

  def test_drawer_item_click_closes_even_when_item_is_already_selected
    start
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/", "selected" => true },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))
    drawer = stack.first.props["drawer"]
    home = controls_of(drawer).first
    @sent.clear

    @page.dispatch_event(target: home.wire_id, name: "click", data: nil)

    assert_equal 1, stack.length, "clicking the active drawer item does not reload the current body"
    assert @sent.any? { |_action, payload| payload["control_id"] == stack.first.wire_id && payload.to_s.include?("close_drawer") },
           "clicking the active drawer item still closes the drawer"
  end

  def test_refreshed_drawer_item_click_closes_after_native_back
    start
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/", "selected" => true },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))
    action("push", "/settings", "title" => "Settings", "leading" => { "icon" => "close", "action" => "back" })
    @page.dispatch_event(target: 1, name: "view_pop", data: nil)
    settings = controls_of(stack.first.props["drawer"]).last
    @sent.clear

    @page.dispatch_event(target: settings.wire_id, name: "click", data: nil)

    assert @sent.any? { |_action, payload| payload["control_id"] == stack.first.wire_id && payload.to_s.include?("close_drawer") },
           "clicking a refreshed drawer row closes after native back"
    assert_equal "https://myapp.com/settings", top_webview.props["url"]
  end

  def test_drawer_selection_closes_the_drawer_owning_view_when_another_screen_is_on_top
    start
    root = stack.first
    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/" },
      { "label" => "Settings", "icon" => "settings", "url" => "/settings", "action" => "push" }
    ] })}))
    drawer = root.props["drawer"]
    action("push", "/details", "title" => "Details", "leading" => { "icon" => "menu", "action" => "drawer" })
    top = stack.last
    @sent.clear

    @page.dispatch_event(target: drawer.wire_id, name: "change", data: { "value" => 1 })

    assert @sent.any? { |_action, payload| payload["control_id"] == root.wire_id && payload.to_s.include?("close_drawer") },
           "a drawer event closes the view that owns the drawer"
    assert_same root, top
    assert_equal "https://myapp.com/settings", top_webview.props["url"]
  end

  def test_duplicate_drawer_message_does_not_rebuild_the_webview_screen
    start
    payload = { "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/" },
      { "label" => "Profile", "icon" => "person", "url" => "/profile" }
    ] }

    post("ruflet:drawer:#{JSON.generate(payload)}")
    view = stack.first
    webview = top_webview

    post("ruflet:drawer:#{JSON.generate(payload)}")
    assert_same view, stack.first, "same drawer payload should not recreate the view"
    assert_same webview, top_webview, "same drawer payload should not recreate the WebView"
  end

  # The drawer is promoted onto the live root view via an in-place control patch
  # (id == the view's wire id), exactly like the appbar/bottomnav/rail. A
  # page-level `views` resend (id == 1) re-serializes every view as a full
  # object, which on the client tears down and reloads the screen's WebView —
  # the body flashes the shimmer twice and the WebView's console channel
  # detaches, so adapter actions (share/copy/navigate) stop working after the
  # first interaction.
  def test_drawer_promotion_patches_the_view_in_place_not_a_full_views_resend
    start(title: "Demo")
    view = stack.first
    @sent.clear

    post(%(ruflet:drawer:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/" },
      { "label" => "Profile", "icon" => "person", "url" => "/profile" }
    ] })}))

    patch_controls = @sent.select { |action, _payload| action == Ruflet::Protocol::ACTIONS[:patch_control] }
    refute_empty patch_controls, "promoting a drawer must emit a control patch"

    assert patch_controls.any? { |_action, payload| payload["id"] == view.wire_id },
           "drawer should patch the mounted view in place (id == view wire id)"

    views_resend = patch_controls.any? do |_action, payload|
      payload["id"] == 1 && payload["patch"].to_s.include?("views")
    end
    refute views_resend, "drawer promotion must not re-send the whole views list (that reloads the WebView)"
  end

  def test_rail_message_wraps_the_current_body_for_desktop_navigation
    start
    view = stack.first
    webview = top_webview
    post(%(ruflet:rail:#{JSON.generate({ "extended" => true, "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/", "selected" => true },
      { "label" => "Inbox", "icon" => "mail", "url" => "/inbox" }
    ] })}))

    row = body_of(stack.first)
    rail = find(row, "navigationrail")
    refute_nil rail, "ruflet-rail builds a native NavigationRail"
    assert_same view, stack.first, "promoting rail should patch the mounted view in place"
    assert_same webview, top_webview, "promoting rail should not recreate the WebView"
    assert_equal true, rail.props["extended"]
    assert_equal 2, Array(rail.props["destinations"]).length
    assert_equal "stack", controls_of(row).last.type
  end

  def test_rail_selection_switches_to_the_destination_url
    start
    post(%(ruflet:rail:#{JSON.generate({ "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/" },
      { "label" => "Inbox", "icon" => "mail", "url" => "/inbox" }
    ] })}))
    rail = find(stack.first, "navigationrail")

    @page.dispatch_event(target: rail.wire_id, name: "change", data: { "value" => 1 })

    assert_equal 1, stack.length
    assert_equal "https://myapp.com/inbox", top_webview.props["url"]
  end

  def test_duplicate_rail_message_does_not_rebuild_the_webview_screen
    start
    payload = { "items" => [
      { "label" => "Home", "icon" => "home", "url" => "/" },
      { "label" => "Profile", "icon" => "person", "url" => "/profile" }
    ] }

    post("ruflet:rail:#{JSON.generate(payload)}")
    view = stack.first
    webview = top_webview

    post("ruflet:rail:#{JSON.generate(payload)}")
    assert_same view, stack.first, "same rail payload should not recreate the view"
    assert_same webview, top_webview, "same rail payload should not recreate the WebView"
  end

  # --- native dialog / toast ---------------------------------------------

  def test_dialog_message_opens_a_native_alert_dialog
    start
    post(%(ruflet:action:#{JSON.generate({ "component" => "dialog", "title" => "Delete?", "content" => "This cannot be undone." })}))
    dialog = @page.instance_variable_get(:@dialogs).last
    refute_nil dialog
    assert_equal "alertdialog", dialog.type
    assert_equal true, dialog.props["adaptive"]
    assert_equal "Delete?", find(dialog.props["title"], "text").props["value"]
    assert_equal "This cannot be undone.", find(dialog.props["content"], "text").props["value"]
  end

  def test_dialog_ok_closes_the_visible_native_dialog
    start
    post(%(ruflet:action:#{JSON.generate({ "component" => "dialog", "title" => "Delete?", "content" => "This cannot be undone." })}))
    dialog = @page.instance_variable_get(:@dialogs).last
    ok = Array(dialog.props["actions"]).last
    @sent.clear

    ok.emit("click", Ruflet::Event.new(name: "click", target: ok.wire_id, raw_data: nil, page: @page, control: ok))

    assert_equal false, dialog.props["open"]
    assert @sent.any? { |_action, payload| payload.to_s.include?('"open"=>false') || payload.to_s.include?('"open", false') },
           "OK must patch the dialog open=false so the client pops the visible route"

    @page.dispatch_event(target: dialog.wire_id, name: "dismiss", data: nil)
    assert_empty @page.instance_variable_get(:@dialogs)
  end

  def test_dialog_confirm_navigates_and_closes
    start
    post(%(ruflet:action:#{JSON.generate({ "component" => "dialog", "title" => "Open?", "confirm" => "Go", "url" => "https://myapp.com/next", "action" => "push" })}))
    dialog = @page.instance_variable_get(:@dialogs).last
    confirm = Array(dialog.props["actions"]).first
    assert_equal "textbutton", confirm.type

    confirm.emit("click", Ruflet::Event.new(name: "click", target: confirm.wire_id, raw_data: nil, page: @page, control: confirm))
    assert_equal 1, stack.length, "confirm performs the navigation inside the shell"
    assert_equal "https://myapp.com/next", top_webview.props["url"]
  end

  def test_toast_message_sets_a_snackbar
    start
    post(%(ruflet:action:#{JSON.generate({ "component" => "toast", "message" => "Saved", "duration" => "2000" })}))
    snackbar = @page.instance_variable_get(:@snack_bar)
    refute_nil snackbar
    assert_equal "snackbar", snackbar.type
    assert_equal true, snackbar.props["adaptive"]
    assert_equal "Saved", find(snackbar.props["content"], "text").props["value"]
    assert_equal 2000, snackbar.props["duration"]
  end

  def test_bottom_sheet_is_adaptive
    start
    action("sheet", "https://myapp.com/quick")
    sheet = @page.instance_variable_get(:@bottom_sheet)
    assert_equal true, sheet.props["adaptive"]
  end

  def test_share_action_invokes_native_share_service
    start
    @sent.clear
    post(%(ruflet:action:#{JSON.generate({ "component" => "share", "text" => "Hello", "title" => "Greeting" })}))

    assert @sent.any? { |_action, payload| payload.to_s.include?("share_text") && payload.to_s.include?("Hello") }
  end

  def test_share_still_invokes_after_copy_action
    start
    @sent.clear

    post(%(ruflet:action:#{JSON.generate({ "component" => "share", "text" => "Hello", "title" => "Greeting" })}))
    post(%(ruflet:action:#{JSON.generate({ "component" => "clipboard", "text" => "Secret", "toast" => "Copied" })}))
    post(%(ruflet:action:#{JSON.generate({ "component" => "share", "text" => "Hello", "title" => "Greeting" })}))

    share_calls = @sent.count { |_action, payload| payload.to_s.include?("share_text") && payload.to_s.include?("Hello") }
    assert_equal 2, share_calls
  end

  def test_share_hash_url_falls_back_to_current_screen_url
    start
    @sent.clear

    post(%(ruflet:action:#{JSON.generate({ "component" => "share", "url" => "#" })}))

    assert @sent.any? { |_action, payload| payload.to_s.include?("share_uri") && payload.to_s.include?("https://myapp.com") }
  end

  def test_clipboard_action_copies_and_toasts
    start
    @sent.clear
    post(%(ruflet:action:#{JSON.generate({ "component" => "clipboard", "text" => "Secret", "toast" => "Copied" })}))

    assert @sent.any? { |_action, payload| payload.to_s.include?("set") && payload.to_s.include?("Secret") }
    snackbar = @page.instance_variable_get(:@snack_bar)
    assert_equal "Copied", find(snackbar.props["content"], "text").props["value"]
    assert_equal 900, snackbar.props["duration"]
  end

  def test_url_launcher_action_invokes_native_launcher
    start
    @sent.clear
    post(%(ruflet:action:#{JSON.generate({ "component" => "url_launcher", "url" => "https://example.com" })}))

    assert @sent.any? { |_action, payload| payload.to_s.include?("launch_url") && payload.to_s.include?("https://example.com") }
  end

  def test_haptic_action_invokes_haptic_service
    start
    @sent.clear
    post(%(ruflet:action:#{JSON.generate({ "component" => "haptic", "style" => "light" })}))

    assert @sent.any? { |_action, payload| payload.to_s.include?("light_impact") }
  end

  def test_toast_without_a_message_is_ignored
    start
    post(%(ruflet:action:#{JSON.generate({ "component" => "toast", "message" => "" })}))
    assert_nil @page.instance_variable_get(:@snack_bar)
  end

  # --- HTML adapter JS ----------------------------------------------------

  def test_html_adapter_handles_explicit_nav_actions_and_chrome_attributes
    js = Ruflet::Rails::NativeApp.html_adapter_js
    assert_includes js, "ruflet-screen"
    assert_includes js, "ruflet-action"
    assert_includes js, "ruflet-appbar"
    assert_includes js, "ruflet-tabs"
    assert_includes js, "ruflet-drawer"
    assert_includes js, "ruflet-rail"
    refute_includes js, "window.RufletNative"
    refute_includes js, "configuredScreenFor"
    assert_includes js, 'report("action"'
    assert_includes js, 'report("appbar"'
    assert_includes js, 'report("bottomnav"'
    assert_includes js, 'report("drawer"'
    assert_includes js, 'report("rail"'
    refute_includes js, "promotedAppBar"
    refute_includes js, 'report("title"'
    assert_includes js, "data-ruflet-" # view-facing attributes use the ruflet data namespace
  end
end
