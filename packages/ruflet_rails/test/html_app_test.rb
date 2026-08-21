# frozen_string_literal: true

require_relative "test_helper"

# HTML-over-the-wire native app: pages fetched from Rails become screens of
# real Ruflet controls, links push native screens, actions re-render in place.
class RufletHtmlAppTest < Minitest::Test
  # Serves canned HTML per path and records every screen asked for.
  class StubFetcher
    Response = Ruflet::Rails::HtmlDsl::TemplateSource::Response

    attr_reader :requests

    def initialize(pages)
      @pages = pages
      @requests = []
    end

    def fetch(url, params: nil)
      @requests << { url: url, params: params }
      path = URI.parse(url).path
      body = @pages.fetch(path, "<text>missing #{path}</text>")
      body = body.call(params) if body.respond_to?(:call)
      Response.new(body: body, url: url)
    end
  end

  def setup
    @sent = []
    @page = Ruflet::Page.new(session_id: "html", client_details: {},
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

  def start(pages)
    @fetcher = StubFetcher.new(pages)
    Ruflet::Rails.erb_to_native(@page, start_url: "https://app.test/", fetcher: @fetcher)
  end

  def test_renders_the_start_page_as_native_controls
    start("/" => '<column class="p-4"><h1>Home</h1><text>Welcome</text></column>')

    assert_equal 1, @page.views.length
    view = @page.views.first
    assert_equal "/", view.props["route"]

    heading = find(view, "text")
    assert_equal "Home", heading.props["value"]
    assert_equal 32, heading.props["size"]
  end

  def test_link_pushes_a_second_screen_with_unique_route
    app = start(
      "/" => '<a href="/settings">Settings</a>',
      "/settings" => "<html><head><title>Settings</title></head><body><text>prefs</text></body></html>"
    )

    find(@page.views.first, "textbutton").emit("click", nil)

    assert_equal 2, @page.views.length
    refute_equal @page.views.first.props["route"], @page.views.last.props["route"]
    body = @page.views.last.props["controls"] || @page.views.last.children
    assert_equal "prefs", find(body, "text").props["value"]

    # Pushed screen gets a titled AppBar (so native back exists).
    appbar = @page.views.last.props["appbar"]
    assert_equal "Settings", appbar.props["title"].props["value"]

    app.pop
    assert_equal 1, @page.views.length
  end

  def test_action_rerenders_the_screen_in_place
    count = 0
    pages = {
      "/" => -> (_params) { "<text>count #{count}</text><button on-click=\"/inc\">+</button>" },
      "/inc" => -> (_params) { count += 1; "<text>count #{count}</text><button on-click=\"/inc\">+</button>" }
    }
    start(pages)

    assert_equal "count 0", find(@page.views.first, "text").props["value"]
    find(@page.views.first, "button").emit("click", nil)

    assert_equal 1, @page.views.length
    assert_equal "count 1", find(@page.views.first, "text").props["value"]
  end

  def test_form_submits_tracked_field_values
    submitted = nil
    pages = {
      "/" => <<~HTML,
        <html><head><meta name="csrf-token" content="tok-1"></head><body>
          <form action="/session" method="post">
            <input type="text" name="email" value="old@x.y">
            <input type="hidden" name="token" value="h1">
            <input type="submit" value="Go">
          </form>
        </body></html>
      HTML
      "/session" => ->(params) { submitted = params; "<text>done</text>" }
    }
    start(pages)

    view = @page.views.first
    find(view, "textfield").emit("change", { "value" => "new@x.y" })
    find(view, "filledbutton").emit("click", nil)

    assert_equal({ "email" => "new@x.y", "token" => "h1" }, submitted)
    assert_equal "done", find(@page.views.first, "text").props["value"]
  end

  def test_root_navigation_resets_the_stack
    start(
      "/" => '<a href="/a">A</a>',
      "/a" => '<a href="/b" nav="root">B</a>',
      "/b" => "<text>b</text>"
    )

    find(@page.views.first, "textbutton").emit("click", nil)
    assert_equal 2, @page.views.length

    find(@page.views.last, "textbutton").emit("click", nil)
    assert_equal 1, @page.views.length
    assert_equal "b", find(@page.views.first, "text").props["value"]
  end

  def test_bottom_nav_mounts_on_the_view_and_switches_tabs
    start(
      "/" => <<~HTML,
        <appbar title="Chats"></appbar>
        <text>chats</text>
        <bottom-nav>
          <nav-item icon="chat" label="Chats" href="/" selected></nav-item>
          <nav-item icon="call" label="Calls" href="/calls"></nav-item>
        </bottom-nav>
      HTML
      "/calls" => <<~HTML
        <appbar title="Calls"></appbar>
        <text>calls</text>
        <bottom-nav>
          <nav-item icon="chat" label="Chats" href="/"></nav-item>
          <nav-item icon="call" label="Calls" href="/calls" selected></nav-item>
        </bottom-nav>
      HTML
    )

    nav = @page.views.first.props["navigation_bar"]
    assert_equal "navigationbar", nav.type
    assert_equal 2, nav.props["destinations"].length

    nav.emit("change", { "selected_index" => 1 })
    # Tab switch resets to a single root screen showing the Calls tab.
    assert_equal 1, @page.views.length
    # Scope to the body (children), so we don't match the app bar's title text.
    assert_equal "calls", find(@page.views.first.children, "text").props["value"]
    assert_equal "Calls", @page.views.first.props["appbar"].props["title"].props["value"]
  end

  # A `<button service="…">` tap runs a real native platform method on the
  # page (clipboard, share, haptics, …) — not a round-trip to Rails.
  def test_service_button_invokes_a_native_page_method
    calls = []
    @page.define_singleton_method(:set_clipboard) { |value, **_| calls << [:set_clipboard, value] }
    @page.define_singleton_method(:share_text) { |text, **_| calls << [:share_text, text] }
    @page.define_singleton_method(:heavy_impact) { calls << [:heavy_impact] }
    @page.define_singleton_method(:launch_url) { |url, **_| calls << [:launch_url, url] }
    @page.define_singleton_method(:show_dialog) { |_dialog| calls << [:dialog] }
    @page.define_singleton_method(:close_dialog) { |_dialog| nil }

    start(
      "/" => <<~HTML
        <button service="copy" text="Ruflet 🚀">Copy</button>
        <button service="share" text="Look at this">Share</button>
        <button service="haptic" style="heavy">Buzz</button>
        <button service="launch" url="https://ruflet.dev">Open</button>
      HTML
    )

    buttons = find_all(@page.views.first, "button")
    buttons.each { |button| button.emit("click", nil) }

    assert_includes calls, [:set_clipboard, "Ruflet 🚀"]
    assert_includes calls, [:share_text, "Look at this"]
    assert_includes calls, [:heavy_impact]
    assert_includes calls, [:launch_url, "https://ruflet.dev"]
    # Service feedback is presented in a native dialog.
    assert_includes calls, [:dialog]
  end

  # Query services report the returned value in a native result dialog.
  def test_service_button_reports_a_query_result_in_a_dialog
    dialogs = []
    @page.define_singleton_method(:get_clipboard) do |on_result: nil, **_|
      on_result&.call("remembered text", nil)
    end
    @page.define_singleton_method(:show_dialog) do |dialog|
      dialogs << [
        dialog.props["title"].props["value"],
        dialog.props["content"].props["value"]
      ]
    end
    @page.define_singleton_method(:close_dialog) { |_dialog| nil }

    start("/" => '<button service="paste">Read clipboard</button>')
    find_all(@page.views.first, "button").first.emit("click", nil)

    assert_includes dialogs, ["Clipboard", "remembered text"]
  end

  # A failed native call surfaces the error instead of failing silently.
  def test_service_button_reports_an_error_in_a_dialog
    dialogs = []
    @page.define_singleton_method(:get_connectivity) do |on_result: nil, **_|
      on_result&.call(nil, "radio offline")
    end
    @page.define_singleton_method(:show_dialog) do |dialog|
      dialogs << [
        dialog.props["title"].props["value"],
        dialog.props["content"].props["value"]
      ]
    end
    @page.define_singleton_method(:close_dialog) { |_dialog| nil }

    start("/" => '<button service="connectivity">Check</button>')
    find_all(@page.views.first, "button").first.emit("click", nil)

    assert_includes dialogs, ["Connectivity failed", "radio offline"]
  end

  def test_service_dialog_close_button_closes_and_later_results_reuse_it
    value = "first result"
    @page.define_singleton_method(:get_clipboard) do |on_result: nil, **_|
      on_result&.call(value, nil)
    end

    start("/" => '<button service="paste">Read clipboard</button>')
    button = find_all(@page.views.first, "button").first
    button.emit("click", nil)

    dialogs = @page.instance_variable_get(:@dialogs)
    assert_equal 1, dialogs.length
    dialog = dialogs.first
    assert_equal true, dialog.props["open"]

    find(dialog, "textbutton").emit("click", nil)
    assert_equal false, dialog.props["open"]

    value = "second result"
    button.emit("click", nil)
    assert_equal 1, dialogs.length
    assert_same dialog, dialogs.first
    assert_equal true, dialog.props["open"]
    assert_equal "second result", dialog.props["content"].props["value"]
  end

  def test_an_older_timeout_cannot_replace_the_latest_service_result
    callbacks = []
    @page.define_singleton_method(:get_connectivity) do |on_result: nil, **_|
      callbacks << on_result
    end

    start("/" => '<button service="connectivity">Check</button>')
    button = find_all(@page.views.first, "button").first
    button.emit("click", nil)
    button.emit("click", nil)

    callbacks.first.call(nil, "execution expired")
    assert_empty @page.instance_variable_get(:@dialogs)

    callbacks.last.call("wifi", nil)
    dialog = @page.instance_variable_get(:@dialogs).first
    assert_equal "Connectivity", dialog.props["title"].props["value"]
    assert_equal "wifi", dialog.props["content"].props["value"]
  end

  def test_camera_helper_flow_updates_inline_status_and_enables_capture
    calls = []
    @page.define_singleton_method(:invoke) do |control, method, args: nil, timeout: 10, on_result: nil|
      calls << [control.id, method, args, timeout]
      case method
      when "get_available_cameras"
        on_result&.call([{ "name" => "back", "lens_direction" => "back" }], nil)
      when "initialize"
        on_result&.call(nil, nil)
      end
    end

    start(
      "/" => <<~HTML
        <text id="camera-status">Waiting</text>
        <camera id="demo-camera" preview-enabled></camera>
        <button service="camera-open" target="demo-camera"
                result-target="camera-status"
                capture-target="camera-capture-button">Open</button>
        <button id="camera-capture-button" disabled>Capture</button>
      HTML
    )
    find_all(@page.views.first, "button").first.emit("click", nil)

    assert_equal %w[get_available_cameras initialize], calls.map { |call| call[1] }
    assert_equal "Camera initialized and preview is ready.",
                 @page.get_control("camera-status").props["value"]
    assert_equal false, @page.get_control("camera-capture-button").props["disabled"]
    assert_empty @page.instance_variable_get(:@dialogs)
  end

  def test_studio_style_extension_event_updates_an_erb_status_target
    start(
      "/" => <<~HTML
        <text id="rive-status">Ready</text>
        <rive id="demo-rive" src="sample.riv"
              on-state-change-target="rive-status"
              on-state-change-prefix="State: "></rive>
      HTML
    )

    rive = @page.get_control("demo-rive")
    event = Struct.new(:data).new({ "state" => "playing" })
    assert rive.emit("state_change", event)
    assert_equal "State: playing", @page.get_control("rive-status").props["value"]
  end

  def test_service_result_can_update_inline_like_ruflet_studio
    @page.define_singleton_method(:get_connectivity) do |on_result: nil, **_|
      on_result&.call(["wifi"], nil)
    end
    start(
      "/" => <<~HTML
        <text id="connectivity-status">Ready</text>
        <button service="connectivity" result-target="connectivity-status">Refresh</button>
      HTML
    )

    find_all(@page.views.first, "button").first.emit("click", nil)
    assert_equal "wifi", @page.get_control("connectivity-status").props["value"]
    assert_empty @page.instance_variable_get(:@dialogs)
  end

  def test_generic_service_button_invokes_any_registered_service_method
    calls = []
    @page.define_singleton_method(:invoke) do |control, method, args: nil, timeout: 10, on_result: nil|
      calls << [control.type, method, args, timeout]
      on_result&.call("granted", nil)
    end
    @page.define_singleton_method(:show_dialog) { |_dialog| nil }
    @page.define_singleton_method(:close_dialog) { |_dialog| nil }

    start(
      "/" => <<~HTML
        <button service="permission-handler" method="request"
                args='{"permission":"camera"}' timeout="4">Allow camera</button>
      HTML
    )
    find_all(@page.views.first, "button").first.emit("click", nil)

    assert_equal [["permissionhandler", "request", { "permission" => "camera" }, 4.0]], calls
  end

  def test_audio_recorder_requests_microphone_then_records_in_documents
    calls = []
    @page.define_singleton_method(:get_application_documents_directory) do |on_result: nil, **_|
      on_result&.call("/device/Documents", nil)
    end
    @page.define_singleton_method(:invoke) do |control, method, args: nil, timeout: 10, on_result: nil|
      calls << [control.type, method, args, timeout]
      result = control.type == "permissionhandler" ? "granted" : true
      on_result&.call(result, nil)
    end

    start(
      "/" => <<~HTML
        <audio-recorder></audio-recorder>
        <permission-handler></permission-handler>
        <storage-paths></storage-paths>
        <text id="recorder-status">Ready</text>
        <button service="audio-recorder-start" file-name="voice.wav"
                result-target="recorder-status">Record</button>
      HTML
    )
    find_all(@page.views.first, "button").first.emit("click", nil)

    assert_equal ["permissionhandler", "request", { "permission" => "microphone" }], calls[0][0, 3]
    assert_equal ["audiorecorder", "start_recording"], calls[1][0, 2]
    assert_equal "/device/Documents/voice.wav", calls[1][2]["output_path"]
    assert_equal({ "encoder" => "wav" }, calls[1][2]["configuration"])
    assert_equal "Recording… Speak now.",
                 @page.get_control("recorder-status").props["value"]
  end

  def test_audio_recorder_does_not_claim_recording_when_native_start_returns_false
    @page.define_singleton_method(:get_application_documents_directory) do |on_result: nil, **_|
      on_result&.call("/device/Documents", nil)
    end
    @page.define_singleton_method(:invoke) do |control, _method, args: nil, timeout: 10, on_result: nil|
      on_result&.call(control.type == "permissionhandler" ? "granted" : false, nil)
    end

    start(
      "/" => '<audio-recorder></audio-recorder><permission-handler></permission-handler>' \
             '<text id="recorder-status">Ready</text>' \
             '<button service="audio-recorder-start" result-target="recorder-status">Record</button>'
    )
    find_all(@page.views.first, "button").first.emit("click", nil)

    assert_equal "The recorder could not start.",
                 @page.get_control("recorder-status").props["value"]
  end

  def test_audio_recorder_animates_while_recording_and_autoplays_after_stop
    recording_paths = []
    documents_requests = 0
    permission_requests = 0
    @page.define_singleton_method(:get_application_documents_directory) do |on_result: nil, **_|
      documents_requests += 1
      on_result&.call("/device/Documents", nil)
    end
    @page.define_singleton_method(:invoke) do |control, method, args: nil, timeout: 10, on_result: nil|
      # Completed audio players may never acknowledge release. Starting the
      # next recording must not depend on that callback.
      next if control.type == "audio" && method == "release"

      result = if control.type == "permissionhandler"
                 permission_requests += 1
                 "granted"
               elsif method == "start_recording"
                 recording_paths << args["output_path"]
                 true
               elsif method == "stop_recording"
                 recording_paths.last
               else
                 true
               end
      on_result&.call(result, nil)
    end

    start(
      "/" => <<~HTML
        <audio-recorder></audio-recorder>
        <permission-handler></permission-handler>
        <storage-paths></storage-paths>
        <spinkit id="recorder-pulse" variant="pulse" visible="false"></spinkit>
        <text id="recorder-status">Ready</text>
        <button id="recorder-record" service="audio-recorder-start"
                result-target="recorder-status" indicator-target="recorder-pulse"
                record-target="recorder-record" stop-target="recorder-stop">Record</button>
        <button id="recorder-stop" service="audio-recorder-stop" disabled
                result-target="recorder-status" indicator-target="recorder-pulse"
                record-target="recorder-record" stop-target="recorder-stop">Stop</button>
      HTML
    )

    record, stop = find_all(@page.views.first, "button")
    record.emit("click", nil)
    assert_equal true, @page.get_control("recorder-pulse").props["visible"]
    assert_equal true, record.props["disabled"]
    assert_equal false, stop.props["disabled"]
    assert_equal "Recording… Speak now.", @page.get_control("recorder-status").props["value"]

    stop.emit("click", nil)
    assert_equal false, @page.get_control("recorder-pulse").props["visible"]
    assert_equal false, record.props["disabled"]
    assert_equal true, stop.props["disabled"]
    player = @page.services.find { |service| service.type == "audio" }
    assert_equal "/device/Documents/ruflet_recording_1.wav", player.props["src"]
    assert_equal true, player.props["autoplay"]
    assert_equal "Saved. Playing your recording…",
                 @page.get_control("recorder-status").props["value"]

    player.emit("state_change", Struct.new(:data).new({ "state" => "completed" }))
    assert_equal "Recording saved and playback finished.",
                 @page.get_control("recorder-status").props["value"]

    record.emit("click", nil)
    assert_equal [
      "/device/Documents/ruflet_recording_1.wav",
      "/device/Documents/ruflet_recording_2.wav"
    ], recording_paths
    assert_equal 1, documents_requests
    assert_equal 1, permission_requests
    assert_equal true, @page.get_control("recorder-pulse").props["visible"]
    assert_equal true, record.props["disabled"]
    assert_equal false, stop.props["disabled"]
    assert_equal "Recording… Speak now.", @page.get_control("recorder-status").props["value"]

    # A late completion event from the released first playback cannot reset the
    # status or controls for the second recording session.
    player.emit("state_change", Struct.new(:data).new({ "state" => "completed" }))
    assert_equal "Recording… Speak now.", @page.get_control("recorder-status").props["value"]
  end

  def test_service_button_can_invoke_a_mounted_extension_service_by_id
    calls = []
    @page.define_singleton_method(:invoke) do |control, method, args: nil, timeout: 10, on_result: nil|
      calls << [control.id, method, args]
      on_result&.call(nil, nil)
    end
    @page.define_singleton_method(:show_dialog) { |_dialog| nil }
    @page.define_singleton_method(:close_dialog) { |_dialog| nil }

    start(
      "/" => <<~HTML
        <audio id="player" src="https://example.test/song.mp3"></audio>
        <button service="control" target="player" method="seek" position="2000">Seek</button>
      HTML
    )
    assert_equal ["audio"], @page.services.map(&:type)
    assert_nil find(@page.views.first, "audio")
    find_all(@page.views.first, "button").first.emit("click", nil)

    assert_equal [["player", "seek", { "position" => 2000 }]], calls
  end

  def find_all(node, type, found = [])
    case node
    when Ruflet::Control
      found << node if node.type == type
      node.props.each_value { |v| find_all(v, type, found) }
      node.children.each { |c| find_all(c, type, found) }
    when Array
      node.each { |v| find_all(v, type, found) }
    end
    found
  end

  # A slow service result that lands after the user has navigated away must not
  # pop a stray dialog on the new screen (the "flash expired" alert bug).
  def test_service_result_after_navigation_is_dropped_not_shown_as_dialog
    dialogs = []
    captured = nil
    @page.define_singleton_method(:show_dialog) { |dialog| dialogs << dialog }
    @page.define_singleton_method(:get_clipboard) { |on_result: nil, **_| captured = on_result }

    start(
      "/" => '<a href="/next">Go</a>' \
             '<button service="paste" result-target="s">Read</button>' \
             '<text id="s">ready</text>',
      "/next" => "<text>next screen</text>"
    )

    find(@page.views.first, "button").emit("click", nil) # taps paste, captures the async callback
    find(@page.views.first, "textbutton").emit("click", nil) # navigates to /next
    assert_equal 2, @page.views.length

    # The clipboard result finally arrives — from the screen we already left.
    captured.call("late clipboard value", nil)

    assert_empty dialogs, "a result for a screen we navigated away from must not open a dialog"
  end

  # `on-load` runs a service the moment the screen mounts — Studio's build-time
  # `refresh_info.call` that populates a panel (battery, …) before any tap.
  def test_on_load_service_runs_when_the_screen_mounts
    @page.define_singleton_method(:get_battery_level) { |on_result: nil, **_| on_result&.call(88, nil) }
    @page.define_singleton_method(:get_battery_state) { |on_result: nil, **_| on_result&.call("full", nil) }
    @page.define_singleton_method(:is_in_battery_save_mode) { |on_result: nil, **_| on_result&.call(false, nil) }

    start(
      "/" => '<text id="battery-status">Battery level: -</text>' \
             '<button service="battery" result-target="battery-status" on-load>Refresh</button>'
    )

    # No tap — the battery panel is already populated, in Studio's exact format.
    status = find(@page.views.first, "text")
    assert_equal "Battery level: 88%\nBattery state: FULL\nBattery saver: OFF", status.props["value"]
  end

  def test_declared_appbar_wins_and_actions_navigate
    start(
      "/" => <<~HTML,
        <appbar title="Inbox">
          <action icon="search" href="/search"/>
        </appbar>
        <text>list</text>
      HTML
      "/search" => "<text>search</text>"
    )

    appbar = @page.views.first.props["appbar"]
    assert_equal "Inbox", appbar.props["title"].props["value"]

    appbar.props["actions"].first.emit("click", nil)
    assert_equal 2, @page.views.length
  end

  # An expanding screen (flex-1 vertical centering) must get a fixed-viewport
  # root: an Expanded inside a scrollable column collapses to an empty body.
  def test_expanding_screens_do_not_scroll_but_normal_screens_do
    start(
      "/" => '<column class="flex-1 items-center justify-center"><text>centered</text></column>'
    )
    body = find(@page.views.first, "column")
    refute body.props.key?("scroll")
    assert_equal true, body.props["expand"]

    start("/" => "<text>long page</text>")
    body = find(@page.views.first, "column")
    assert_equal "auto", body.props["scroll"]
  end

  # A template can hand back an ASCII-8BIT body; binary text values would be
  # packed as msgpack bin and render as byte arrays on the client.
  def test_binary_response_bodies_become_utf8_text
    fetcher = Object.new
    def fetcher.fetch(url, params: nil)
      body = "<text>Ruflet Native — démo</text>".dup.force_encoding(Encoding::ASCII_8BIT)
      Ruflet::Rails::HtmlDsl::TemplateSource::Response.new(body: body, url: url)
    end
    Ruflet::Rails.erb_to_native(@page, start_url: "https://app.test/", fetcher: fetcher)

    value = find(@page.views.first, "text").props["value"]
    assert_equal Encoding::UTF_8, value.encoding
    assert_equal "Ruflet Native — démo", value
  end


  def find_all_text_values(node, values = [])
    case node
    when Ruflet::Control
      values << node.props["value"] if node.type == "text"
      node.props.each_value { |v| find_all_text_values(v, values) }
      node.children.each { |c| find_all_text_values(c, values) }
    when Array
      node.each { |v| find_all_text_values(v, values) }
    end
    values.compact
  end

  def test_fetch_errors_render_an_error_screen
    fetcher = Object.new
    def fetcher.fetch(*, **) = raise "connection refused"
    Ruflet::Rails.erb_to_native(@page, start_url: "https://app.test/", fetcher: fetcher)

    texts = []
    collect = lambda do |node|
      case node
      when Ruflet::Control
        texts << node.props["value"] if node.type == "text"
        node.props.each_value { |v| collect.call(v) }
        node.children.each { |c| collect.call(c) }
      when Array then node.each { |v| collect.call(v) }
      end
    end
    collect.call(@page.views.first)
    assert_includes texts.join(" "), "connection refused"
  end

  # --- one session, many screens ------------------------------------------
  #
  # The screens are Rails renders, but the *session* is not per screen: one
  # Ruflet page, one screen stack held in memory, one fetcher (so one Rails
  # session) for the whole WebSocket connection. These pin that down.

  def test_back_restores_the_retained_view_without_refetching
    app = start(
      "/" => '<a href="/settings">Settings</a>',
      "/settings" => "<text>prefs</text>"
    )

    home_view = @page.views.first
    find(home_view, "textbutton").emit("click", nil)
    assert_equal 2, @page.views.length

    requests_before_back = @fetcher.requests.length
    app.pop

    assert_equal 1, @page.views.length
    assert_equal requests_before_back, @fetcher.requests.length,
                 "going back must not re-fetch the previous screen"
    assert_same home_view, @page.views.first,
                "going back must restore the retained view, not rebuild it"
  end

  def test_one_page_and_one_fetcher_serve_every_screen
    app = start(
      "/" => '<a href="/a">A</a>',
      "/a" => '<a href="/b">B</a>',
      "/b" => "<text>b</text>"
    )

    find(@page.views.first, "textbutton").emit("click", nil)
    find(@page.views.last, "textbutton").emit("click", nil)

    assert_equal 3, @page.views.length
    assert_equal 3, @fetcher.requests.length
    assert_equal %w[/ /a /b], @fetcher.requests.map { |r| URI.parse(r[:url]).path }

    # Every screen went through the one fetcher this session owns, which is
    # what carries the Rails session cookie from screen to screen.
    assert_same @fetcher, app.instance_variable_get(:@fetcher)
  end

  # --- in-place re-render patches, it does not replace ---------------------

  def test_rerender_patches_only_the_controls_whose_props_changed
    count = 0
    markup = lambda { |_params|
      "<column><text>#{count}</text><button on-click=\"post:/up\">Up</button></column>"
    }
    start(
      "/" => markup,
      "/up" => lambda { |params|
        count += 1
        markup.call(params)
      }
    )

    label = find(@page.views.first, "text")
    assert_equal "0", label.props["value"]

    @sent.clear
    find(@page.views.first, "button").emit("click", nil)

    # The shape did not move, so the whole body must not be re-sent: the
    # mounted text control is patched in place.
    assert_equal "1", label.props["value"], "the mounted control must carry the new value"
    refute(@sent.any? { |(_action, payload)| payload.to_s.include?("Up") },
           "a value change must not re-send the button")
  end

  def test_rerender_replaces_the_body_when_the_shape_changes
    shape = "<column><text>one</text></column>"
    app = start(
      "/" => ->(_params) { shape },
      "/toggle" => lambda { |_params|
        shape = "<column><text>one</text><text>two</text></column>"
        shape
      }
    )

    app.action(url: "/toggle")

    texts = []
    collect = lambda do |node|
      case node
      when Ruflet::Control
        texts << node.props["value"] if node.type == "text"
        node.props.each_value { |v| collect.call(v) }
        node.children.each { |c| collect.call(c) }
      when Array then node.each { |v| collect.call(v) }
      end
    end
    collect.call(@page.views.last)

    assert_includes texts, "two", "a new control must appear when the shape grows"
  end

  def test_state_written_on_one_screen_is_visible_on_the_next
    store = []
    app = start(
      "/" => '<button on-click="post:/items">Add</button>',
      "/items" => lambda { |_params|
        store << "item"
        "<text>added</text>"
      },
      "/list" => ->(_params) { "<text>#{store.length} items</text>" }
    )

    find(@page.views.first, "button").emit("click", nil)
    app.navigate("/list", "push")

    texts = []
    collect = lambda do |node|
      case node
      when Ruflet::Control
        texts << node.props["value"] if node.type == "text"
        node.props.each_value { |v| collect.call(v) }
        node.children.each { |c| collect.call(c) }
      when Array then node.each { |v| collect.call(v) }
      end
    end
    collect.call(@page.views.last)

    assert_includes texts, "1 items",
                    "server state written by one screen must be readable by the next"
  end

  # --- path-only screens ---------------------------------------------------
  #
  # Nothing here travels over the network, so a screen can be named by path
  # alone. The host, when one is needed at all, comes from the live WebSocket.

  def test_a_path_start_url_renders_without_naming_a_host
    @fetcher = StubFetcher.new("/native" => "<text>Native home</text>")
    Ruflet::Rails.erb_to_native(@page, start_url: "/native", fetcher: @fetcher)

    assert_equal "/native", @fetcher.requests.first[:url]
    body = @page.views.first.props["controls"] || @page.views.first.children
    assert_equal "Native home", find(body, "text").props["value"]
  end

  def test_a_path_start_url_resolves_absolute_and_relative_links
    @fetcher = StubFetcher.new(
      "/native" => '<a href="/native/counter">Counter</a>',
      "/native/counter" => '<a href="detail">Detail</a>',
      "/native/detail" => "<text>Detail screen</text>"
    )
    app = Ruflet::Rails.erb_to_native(@page, start_url: "/native", fetcher: @fetcher)

    find(@page.views.first, "textbutton").emit("click", nil)
    find(@page.views.last, "textbutton").emit("click", nil)

    assert_equal %w[/native /native/counter /native/detail], @fetcher.requests.map { |r| r[:url] }
    body = @page.views.last.props["controls"] || @page.views.last.children
    assert_equal "Detail screen", find(body, "text").props["value"]
    assert_equal 3, @page.views.length
    app.pop
  end

  # Dot segments follow ordinary URI rules: the base directory of
  # /native/counter is /native/, so ".." lands at the root.
  def test_a_path_start_url_walks_up_a_relative_segment
    @fetcher = StubFetcher.new(
      "/native/counter" => '<a href="../form">Form</a>',
      "/form" => "<text>Form screen</text>"
    )
    Ruflet::Rails.erb_to_native(@page, start_url: "/native/counter", fetcher: @fetcher)
    find(@page.views.first, "textbutton").emit("click", nil)

    assert_equal "/form", @fetcher.requests.last[:url]
    body = @page.views.last.props["controls"] || @page.views.last.children
    assert_equal "Form screen", find(body, "text").props["value"]
  end

  def test_a_path_start_url_keeps_query_strings_on_relative_links
    @fetcher = StubFetcher.new("/native" => '<a href="search?q=ada">Search</a>',
                               "/search" => "<text>Results</text>")
    Ruflet::Rails.erb_to_native(@page, start_url: "/native", fetcher: @fetcher)
    find(@page.views.first, "textbutton").emit("click", nil)

    assert_equal "/search?q=ada", @fetcher.requests.last[:url]
  end

  # --- media URLs ----------------------------------------------------------
  #
  # Screens are dispatched in-process, but the client loads media itself over
  # HTTP, so those URLs — and only those — still need a real host.

  def with_backend_url(url)
    previous = Ruflet::Rails.config.backend_url
    Ruflet::Rails.config.backend_url = url
    yield
  ensure
    Ruflet::Rails.config.backend_url = previous
  end

  def render_and_find(markup, type)
    @fetcher = StubFetcher.new("/native" => markup)
    Ruflet::Rails.erb_to_native(@page, start_url: "/native", fetcher: @fetcher)
    find(@page.views.first, type)
  end

  def test_a_rails_hosted_image_is_resolved_against_the_connection_host
    with_backend_url("https://app.test") do
      image = render_and_find('<img src="/assets/logo.png">', "image")

      assert_equal "https://app.test/assets/logo.png", image.props["src"]
    end
  end

  def test_an_avatar_image_is_resolved_too
    with_backend_url("https://app.test") do
      avatar = render_and_find('<avatar src="/me.png">AM</avatar>', "circleavatar")

      assert_equal "https://app.test/me.png", avatar.props["foreground_image_src"]
    end
  end

  def test_an_external_media_url_is_left_alone
    with_backend_url("https://app.test") do
      image = render_and_find('<img src="https://cdn.example.com/a.png">', "image")

      assert_equal "https://cdn.example.com/a.png", image.props["src"]
    end
  end

  def test_a_data_uri_and_a_bundled_asset_name_are_left_alone
    with_backend_url("https://app.test") do
      assert_equal "data:image/png;base64,AAAA",
                   render_and_find('<img src="data:image/png;base64,AAAA">', "image").props["src"]
      assert_equal "logo.png", render_and_find('<img src="logo.png">', "image").props["src"]
      assert_equal "//cdn.example.com/a.png",
                   render_and_find('<img src="//cdn.example.com/a.png">', "image").props["src"]
    end
  end

  def test_media_urls_on_other_controls_are_resolved_by_attribute_name
    with_backend_url("https://app.test") do
      rive = render_and_find('<rive src="/anim.riv" url="/fallback.riv"></rive>', "rive")

      assert_equal "https://app.test/anim.riv", rive.props["src"]
      assert_equal "https://app.test/fallback.riv", rive.props["url"]
    end
  end

  def test_navigation_hrefs_are_never_turned_into_media_urls
    with_backend_url("https://app.test") do
      @fetcher = StubFetcher.new("/native" => '<a href="/settings">Settings</a>',
                                 "/settings" => "<text>prefs</text>")
      Ruflet::Rails.erb_to_native(@page, start_url: "/native", fetcher: @fetcher)
      find(@page.views.first, "textbutton").emit("click", nil)

      assert_equal "/settings", @fetcher.requests.last[:url],
                   "navigation stays a path — it is dispatched in-process, not fetched"
    end
  end

  def test_an_absolute_start_url_still_produces_absolute_screen_urls
    @fetcher = StubFetcher.new("/" => '<a href="/settings">Settings</a>',
                               "/settings" => "<text>prefs</text>")
    Ruflet::Rails.erb_to_native(@page, start_url: "https://app.test/", fetcher: @fetcher)
    find(@page.views.first, "textbutton").emit("click", nil)

    assert_equal "https://app.test/settings", @fetcher.requests.last[:url]
  end
end
