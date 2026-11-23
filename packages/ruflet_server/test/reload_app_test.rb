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

  ACTIONS = Ruflet::Protocol::ACTIONS

  # The app's directory, as `ruflet run` sets it: errors point at the first
  # frame in it, here this file.
  def setup
    @previous_watch_root = ENV["RUFLET_WATCH_ROOT"]
    ENV["RUFLET_WATCH_ROOT"] = __dir__
  end

  def teardown
    @previous_watch_root.nil? ? ENV.delete("RUFLET_WATCH_ROOT") : ENV["RUFLET_WATCH_ROOT"] = @previous_watch_root
  end

  def frames(ws)
    ws.sent.map { |raw| Ruflet::WireCodec.unpack(raw) }
  end

  def view_texts(frame, acc = [])
    case frame
    when Hash
      acc << frame["value"] if frame["_c"] == "Text"
      frame.each_value { |value| view_texts(value, acc) }
    when Array then frame.each { |value| view_texts(value, acc) }
    end
    acc
  end

  def register_client(server)
    ws = FakeWs.new
    server.instance_variable_get(:@connections)[ws.session_key] = ws
    begin
      server.send(:handle_message, ws, Ruflet::WireCodec.pack([ACTIONS[:register_client], { "session_id" => nil, "page" => { "route" => "/" } }]))
    end
    [ws, server.instance_variable_get(:@sessions)[ws.session_key]]
  end

  def text(id) = Ruflet::Control.new(type: "Text", id: id, value: id)

  # The app as a hot reload edits it: :good renders header, body and footer;
  # :mid raises after adding two controls; :early raises on its first line.
  def editable_server(mode)
    Ruflet::Server.new(port: 0) do |page|
      page.title = "App"
      raise NameError, "undefined local variable or method 'oops' for main" if mode[0] == :early

      page.add(text("header"))
      page.add(text("body"))
      raise NameError, "undefined local variable or method 'footer_text' for main" if mode[0] == :mid

      page.add(text("footer"))
    end
  end

  def test_a_reload_whose_block_raises_mid_render_keeps_the_previous_ui
    mode = [:good]
    server = editable_server(mode)
    ws, page = nil
    _, err = capture_io { ws, page = register_client(server) }
    assert_empty err
    ws.sent.clear

    mode[0] = :mid
    result = nil
    _, err = capture_io { result = server.reload_app! }

    assert_equal false, result, "reload_app! reports that the block raised"
    assert_empty ws.sent, "a half-built page never reaches the client"
    assert_equal %w[header body footer], page.controls.map(&:id), "the session keeps its previous state"
    assert_equal "App", page.title
    first_line, location = err.lines
    assert_equal "reload error: NameError: undefined local variable or method 'footer_text' for main\n", first_line
    assert_match(/\A  at .*reload_app_test\.rb:\d+:in /, location, "the error says where in the app it was raised")
  end

  def test_a_reload_whose_block_raises_on_its_first_line_keeps_the_tree_and_its_handlers
    mode = [:good]
    clicks = []
    server = Ruflet::Server.new(port: 0) do |page|
      raise NameError, "undefined local variable or method 'oops' for main" if mode[0] == :early

      page.add(text("header"))
      page.add(Ruflet::Control.new(type: "Button", id: "go", content: "Go", on_click: ->(_e) { clicks << :v1 }))
    end
    ws, page = nil
    capture_io { ws, page = register_client(server) }
    ws.sent.clear

    mode[0] = :early
    capture_io { assert_equal false, server.reload_app! }
    assert_empty ws.sent

    button = page.controls.last
    page.dispatch_event(target: button.wire_id, name: "click", data: nil)
    assert_equal [:v1], clicks, "the previous UI keeps working"

    page.add(text("row"))
    assert_equal %w[header row], view_texts(frames(ws).last),
                 "a later page.add patches the previous tree, not an emptied one"
  end

  def test_a_reload_after_a_failed_one_renders_the_new_code
    mode = [:good]
    server = editable_server(mode)
    ws, page = nil
    capture_io { ws, page = register_client(server) }

    mode[0] = :mid
    capture_io { server.reload_app! }
    ws.sent.clear
    mode[0] = :good
    result = nil
    _, err = capture_io { result = server.reload_app! }

    assert_equal true, result
    assert_empty err
    assert_equal %w[header body footer], page.controls.map(&:id)
    last_view = frames(ws).reverse.find { |action, payload| action == ACTIONS[:patch_control] && payload["id"] == 1 }
    assert_equal %w[header body footer], view_texts(last_view)
  end

  def test_a_crashed_first_render_recovers_on_the_next_reload_that_succeeds
    mode = [:mid]
    server = editable_server(mode)
    ws, crashed_page = nil
    _, err = capture_io { ws, crashed_page = register_client(server) }

    crashed = frames(ws).find { |action, _| action == ACTIONS[:session_crashed] }
    assert_equal "undefined local variable or method 'footer_text' for main", crashed[1]["message"]
    assert_includes err, "handle_message error: NameError"
    ws.sent.clear

    # What the crashed page sends is not kept: it never registers.
    50.times { crashed_page.add(text("noise")) }
    buffered = crashed_page.instance_variable_get(:@sender).binding.local_variable_get(:buffered)
    assert_empty buffered, "a page whose first render raised holds nothing"

    mode[0] = :good
    result = nil
    capture_io { result = server.reload_app! }

    assert_equal true, result
    action, response = frames(ws).first
    assert_equal ACTIONS[:register_client], action, "the client gets the register response it waits for"
    assert_equal %w[header body footer], view_texts(response["page_patch"]["views"])
    page = server.instance_variable_get(:@sessions)[ws.session_key]
    refute_same crashed_page, page
    assert_equal crashed_page.session_id, page.session_id

    ws.sent.clear
    page.add(text("live"))
    refute_empty ws.sent, "the recovered session sends live"

    ws.sent.clear
    capture_io { assert_equal true, server.reload_app! }
    assert_equal [ACTIONS[:patch_control]], frames(ws).map(&:first).uniq, "later reloads patch it as usual"
  end

  def test_a_crashed_first_render_that_raises_again_on_reload_shows_the_new_error
    mode = [:mid]
    server = editable_server(mode)
    ws = nil
    capture_io { ws, = register_client(server) }
    ws.sent.clear

    mode[0] = :early
    result = nil
    _, err = capture_io { result = server.reload_app! }

    assert_equal false, result
    assert_equal [[ACTIONS[:session_crashed], { "message" => "undefined local variable or method 'oops' for main" }]], frames(ws)
    assert_includes err, "reload error: NameError: undefined local variable or method 'oops' for main"

    ws.sent.clear
    mode[0] = :good
    capture_io { assert_equal true, server.reload_app! }
    assert_equal ACTIONS[:register_client], frames(ws).first.first
  end

  def test_a_failed_reload_prints_the_whole_backtrace_under_ruflet_debug
    mode = [:good]
    server = editable_server(mode)
    capture_io { register_client(server) }
    mode[0] = :mid
    previous = ENV["RUFLET_DEBUG"]
    ENV["RUFLET_DEBUG"] = "1"
    _, err = capture_io { server.reload_app! }

    lines = err.lines
    assert_equal "reload error: NameError: undefined local variable or method 'footer_text' for main\n", lines.first
    assert_operator lines.length, :>, 3
    assert(lines.any? { |line| line.include?("ruflet/server.rb") }, "every frame, the server's too")
    refute(lines.any? { |line| line.start_with?("  at ") })
  ensure
    previous.nil? ? ENV.delete("RUFLET_DEBUG") : ENV["RUFLET_DEBUG"] = previous
  end

  def test_a_raising_handler_says_where_in_the_app_it_raised
    server = Ruflet::Server.new(port: 0) do |page|
      page.add(Ruflet::Control.new(type: "Button", id: "go", content: "Go", on_click: ->(_e) { nil.upcase }))
    end
    ws, page = nil
    capture_io { ws, page = register_client(server) }

    _, err = capture_io do
      server.send(:handle_message, ws, Ruflet::WireCodec.pack([ACTIONS[:control_event], { "target" => page.controls.first.wire_id, "name" => "click", "data" => nil }]))
    end

    first_line, location = err.lines
    assert_equal "[embedded server] handle_message error: NoMethodError: undefined method 'upcase' for nil\n", first_line
    assert_match(/\A  at .*reload_app_test\.rb:\d+:in /, location)
  end

  def test_session_crashed_says_where_under_ruflet_run
    previous = ENV["RUFLET_TARGET"]
    ENV["RUFLET_TARGET"] = "desktop"
    server = Ruflet::Server.new(port: 0) { |_page| raise "boom" }
    ws = nil
    capture_io { ws, = register_client(server) }

    message = frames(ws).find { |action, _| action == ACTIONS[:session_crashed] }[1]["message"]
    first, details = message.split("\n", 2)
    assert_equal "boom", first, "the error itself stays the first line"
    assert_match(/\ARuntimeError at .*reload_app_test\.rb:\d+:in /, details)
  ensure
    previous.nil? ? ENV.delete("RUFLET_TARGET") : ENV["RUFLET_TARGET"] = previous
  end
end
