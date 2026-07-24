# frozen_string_literal: true

require_relative "test_helper"

class RufletReloadAppTest < Minitest::Test
  class FakeWs
    attr_reader :sent

    def initialize
      @sent = []
    end

    def session_key
      object_id
    end

    def closed?
      false
    end

    def send_binary(bytes)
      @sent << bytes
    end
  end

  def build_session(server, &sender)
    ws = FakeWs.new
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: {},
      sender: sender || ->(_action, _payload) { nil }
    )
    server.instance_variable_get(:@sessions)[ws.session_key] = page
    server.instance_variable_get(:@connections)[ws.session_key] = ws
    [ws, page]
  end

  def test_register_client_ships_full_state_in_the_register_response
    server = Ruflet::Server.new(port: 0) do |page|
      page.add(Ruflet::Control.new(type: "Text", id: "greeting", value: "hi"))
    end
    ws = FakeWs.new
    server.instance_variable_get(:@connections)[ws.session_key] = ws

    server.send(:on_register_client, ws, { "session_id" => "old-session", "page" => { "route" => "/" } })

    refute_empty ws.sent
    action, response = Ruflet::WireCodec.unpack(ws.sent.first)
    assert_equal Ruflet::Protocol::ACTIONS[:register_client], action
    patch = response["page_patch"]
    # The register response must carry the complete page state: the client
    # merges it by control id (Control.update), the only patch path that a
    # reconnecting client with prior state applies without detaching controls.
    refute_empty patch, "page_patch must not be empty"
    assert patch.key?("views"), "page_patch must include the views"
    assert patch.key?("_dialogs"), "page_patch must include the dialogs container"

    # No separate full view patch should follow — it would replace the
    # instances the response just merged.
    ws.sent.drop(1).each do |raw|
      follow_action, payload = Ruflet::WireCodec.unpack(raw)
      next unless follow_action == Ruflet::Protocol::ACTIONS[:patch_control]

      refute(deep_include?(payload, "views"), "no trailing views patch after register")
    end
  end

  def deep_include?(value, needle)
    case value
    when String then value.include?(needle)
    when Array then value.any? { |v| deep_include?(v, needle) }
    when Hash then value.any? { |k, v| deep_include?(k.to_s, needle) || deep_include?(v, needle) }
    else false
    end
  end

  def test_reload_app_reruns_block_on_the_same_live_page
    seen_pages = []
    server = Ruflet::Server.new(port: 0) { |page| seen_pages << page }
    ws, page = build_session(server)

    server.reload_app!

    # The page object must survive the reload: recreating it re-sends the
    # internal overlay/service/dialogs containers, which detaches their
    # client-side instances and leaves later dialog patches ignored.
    assert_same page, server.instance_variable_get(:@sessions)[ws.session_key]
    assert_equal [page], seen_pages
  end

  def test_reload_app_clears_previous_content_before_rerunning_the_block
    server = Ruflet::Server.new(port: 0) do |page|
      page.add(Ruflet::Control.new(type: "Text", id: "greeting", value: "hi"))
    end
    _ws, page = build_session(server)
    page.add(Ruflet::Control.new(type: "Text", id: "stale", value: "old"))

    server.reload_app!
    server.reload_app!

    assert_equal ["greeting"], page.controls.map(&:id),
                 "reload must clear old content and never accumulate duplicates"
  end

  def test_reload_app_keeps_the_current_route_and_replays_it_for_handler_only_apps
    rendered_routes = []
    server = Ruflet::Server.new(port: 0) do |page|
      page.on_route_change = ->(event) { rendered_routes << page.route }
    end
    _ws, page = build_session(server)
    page.route = "/settings"

    server.reload_app!

    assert_equal "/settings", page.route, "hot reload must not reset the route"
    assert_equal ["/settings"], rendered_routes,
                 "apps rendering only in on_route_change must be replayed onto their current route"
  end

  def test_reload_app_does_not_replay_route_when_the_block_routes_itself
    route_change_calls = 0
    server = Ruflet::Server.new(port: 0) do |page|
      page.on_route_change = ->(event) { route_change_calls += 1 }
      page.go(page.route)
    end
    _ws, page = build_session(server)
    page.route = "/settings"

    server.reload_app!

    assert_equal "/settings", page.route
    assert_equal 1, route_change_calls, "page.go in the block must not be double-fired by the replay"
  end

  def test_reload_clears_page_chrome_the_new_block_no_longer_sets
    with_appbar = true
    server = Ruflet::Server.new(port: 0) do |page|
      page.add(Ruflet::Control.new(type: "Text", id: "body"))
      if with_appbar
        page.appbar = Ruflet::Control.new(type: "AppBar", id: "bar")
        page.floating_action_button = Ruflet::Control.new(type: "FloatingActionButton", id: "fab")
        page.title = "Gallery"
      end
    end
    _ws, page = build_session(server)
    server.reload_app! # first render (build_session does not run the block)
    assert page.appbar, "sanity: first render has an appbar"
    assert page.floating_action_button, "sanity: first render has a FAB"

    # Reloaded code no longer defines any chrome.
    with_appbar = false
    server.reload_app!

    assert_nil page.appbar, "reload must drop an appbar the new block no longer sets"
    assert_nil page.floating_action_button, "reload must drop a FAB the new block no longer sets"
    assert_nil page.title, "reload must clear a title the new block no longer sets"
  end

  def test_reload_app_closes_open_overlays_on_the_outgoing_page
    server = Ruflet::Server.new(port: 0) { |_page| nil }
    close_patches = []
    _ws, page = build_session(server) do |action, payload|
      close_patches << payload if action == Ruflet::Protocol::ACTIONS[:patch_control]
    end

    dialog = Ruflet::Control.new(type: "AlertDialog", id: "dlg")
    sheet = Ruflet::Control.new(type: "BottomSheet", id: "sheet")
    page.show_dialog(dialog)
    page.show_bottom_sheet(sheet)
    assert_equal true, dialog.props["open"]
    assert_equal true, sheet.props["open"]
    close_patches.clear

    server.reload_app!

    assert_equal false, dialog.props["open"], "reload must close the open dialog"
    assert_equal false, sheet.props["open"], "reload must close the open sheet"
    refute_empty close_patches, "closing overlays must be pushed to the client before the swap"
  end
end
