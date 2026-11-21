# frozen_string_literal: true

require_relative "test_helper"

class RufletConnectionProtocolTest < Minitest::Test
  ACTIONS = Ruflet::Protocol::ACTIONS

  class Host
    include Ruflet::ConnectionProtocol
  end

  # A ConnectionProtocol host that records what it logs, as ruflet_rails'
  # LocalServer routes log_connection_error to Rails.logger.
  class AppHost
    include Ruflet::ConnectionProtocol

    attr_reader :logged, :removed

    def initialize(&app)
      @app_block = app
      @sessions = {}
      @sessions_mutex = Mutex.new
      @logged = []
      @removed = []
    end

    def log_connection_error(error)
      @logged << "#{error.class}: #{error.message}"
    end

    def session_removed(page, _ws)
      @removed << page
    end

    def page_for(ws)
      @sessions_mutex.synchronize { @sessions[ws.session_key] }
    end
  end

  # A client connection: frames are read in order, and a frame may be a
  # proc so it can refer to wire ids the register reply assigned.
  class FakeWs
    attr_reader :sent

    def initialize(frames)
      @frames = frames
      @sent = []
      @closed = false
    end

    def session_key = object_id
    def closed? = @closed
    def close = (@closed = true)

    def read_message
      frame = @frames.shift
      frame.respond_to?(:call) ? frame.call : frame
    end

    def send_binary(bytes)
      @sent << bytes
    end

    def actions
      @sent.map { |bytes| Ruflet::WireCodec.unpack(bytes)[0] }
    end
  end

  def pack(action, payload)
    Ruflet::WireCodec.pack([ACTIONS.fetch(action), payload])
  end

  def register_frame
    pack(:register_client, { "session_id" => "s-1", "page" => { "route" => "/" } })
  end

  # An app whose button handler raises on its first click only.
  def failing_once_app(state)
    lambda do |page|
      button = Ruflet.button(content: "Save", on_click: lambda { |_event|
        state[:clicks] += 1
        raise ArgumentError, "validation failed" if state[:clicks] == 1
      })
      page.add(button)
      state[:button] = button
    end
  end

  def test_shared_receiver_accepts_python_output_without_closing_the_connection
    message = Ruflet::WireCodec.pack([
      Ruflet::Protocol::ACTIONS[:python_output],
      { "message" => "renderer diagnostic", "error" => false }
    ])

    assert_nil Host.new.handle_message(Object.new, message)
  end

  def test_shared_receiver_still_rejects_unknown_actions
    message = Ruflet::WireCodec.pack([999, {}])

    error = assert_raises(RuntimeError) { Host.new.handle_message(Object.new, message) }
    assert_equal "Unknown action: 999", error.message
  end

  def test_a_raising_event_handler_is_logged_and_the_connection_keeps_running
    state = { clicks: 0 }
    host = AppHost.new(&failing_once_app(state))
    click = -> { pack(:control_event, { "target" => state[:button].wire_id, "name" => "click", "data" => "" }) }
    ws = FakeWs.new([register_frame, click, click])

    host.run_connection(ws)

    assert_equal 2, state[:clicks], "the click after the failing one still reaches its handler"
    assert_equal ["ArgumentError: validation failed"], host.logged
    refute_includes ws.actions, ACTIONS[:session_crashed]
    assert_equal 1, host.removed.size, "the session ends once, when the client disconnects"
  end

  def test_a_raising_event_handler_leaves_the_session_in_place
    state = { clicks: 0 }
    host = AppHost.new(&failing_once_app(state))
    ws = FakeWs.new([])
    host.handle_message(ws, register_frame)
    page = host.page_for(ws)

    host.handle_message(ws, pack(:control_event, { "target" => state[:button].wire_id, "name" => "click", "data" => "" }))

    assert_same page, host.page_for(ws)
    assert_empty host.removed
    refute ws.closed?
    assert_equal ["ArgumentError: validation failed"], host.logged
  end

  def test_a_raising_page_event_handler_is_logged_too
    host = AppHost.new do |page|
      page.on_route_change = ->(_event) { raise "no such route" }
    end
    ws = FakeWs.new([])
    host.handle_message(ws, register_frame)
    page = host.page_for(ws)

    host.handle_message(ws, pack(:control_event, { "target" => "page", "name" => "route_change", "data" => { "route" => "/missing" } }))

    assert_equal ["RuntimeError: no such route"], host.logged
    assert_same page, host.page_for(ws)
  end

  def test_an_app_that_raises_on_register_still_reports_session_crashed_and_closes
    host = AppHost.new { |_page| raise "boom" }
    ws = FakeWs.new([register_frame])

    host.run_connection(ws)

    assert_includes ws.actions, ACTIONS[:session_crashed]
    assert ws.closed?
    assert_equal ["RuntimeError: boom"], host.logged
  end

  # A host with a session registry, like ruflet_rails' LocalServer.
  class ResumingHost < AppHost
    attr_accessor :refuse_resume
    attr_reader :registry, :resume_requests

    def initialize(&app)
      super
      @registry = {}
      @resume_requests = []
    end

    def resume_session(session_id)
      @registry[session_id]
    end

    def allow_resume?(session_id, ws)
      @resume_requests << [session_id, ws]
      !refuse_resume
    end

    def session_stored(page, _ws)
      @registry[page.session_id] = page
    end
  end

  def register_reply(ws)
    Ruflet::WireCodec.unpack(ws.sent.first)[1]
  end

  def test_a_refused_resume_gets_a_fresh_page_under_a_new_session_id
    renders = 0
    host = ResumingHost.new { |page| renders += 1; page.add(Ruflet.text("hello")) }
    first = FakeWs.new([])
    host.handle_message(first, pack(:register_client, { "session_id" => "", "page" => { "route" => "/" } }))
    owned_id = register_reply(first)["session_id"]

    host.refuse_resume = true
    second = FakeWs.new([])
    host.handle_message(second, pack(:register_client, { "session_id" => owned_id, "page" => { "route" => "/" } }))
    second_id = register_reply(second)["session_id"]

    assert_equal [[owned_id, second]], host.resume_requests
    refute_equal owned_id, second_id
    assert_match(/\A\h{8}-\h{4}-4\h{3}-[89ab]\h{3}-\h{12}\z/, second_id)
    refute_same host.page_for(first), host.page_for(second)
    assert_same host.page_for(first), host.registry[owned_id]
    assert_equal 2, renders
    assert_nil host.page_for(second).client_details["session_id"], "the fresh page must not carry the other client's id"
  end

  def test_an_allowed_resume_reattaches_the_page_as_before
    renders = 0
    host = ResumingHost.new { |_page| renders += 1 }
    first = FakeWs.new([])
    host.handle_message(first, register_frame)
    second = FakeWs.new([])
    host.handle_message(second, register_frame)

    assert_equal "s-1", register_reply(second)["session_id"]
    assert_same host.page_for(first), host.page_for(second)
    assert_equal 1, renders
  end

  def test_registering_without_an_id_does_not_ask_to_resume
    host = ResumingHost.new { |_page| nil }
    ws = FakeWs.new([])
    host.handle_message(ws, pack(:register_client, { "session_id" => nil, "page" => { "route" => "/" } }))

    assert_empty host.resume_requests
    assert_match(/\A\h{8}-\h{4}-4\h{3}-[89ab]\h{3}-\h{12}\z/, register_reply(ws)["session_id"])
  end

  def test_the_default_hook_keeps_the_client_id
    host = AppHost.new { |_page| nil }
    ws = FakeWs.new([])
    host.handle_message(ws, register_frame)

    assert_equal "s-1", register_reply(ws)["session_id"]
    assert_equal "s-1", host.page_for(ws).session_id
  end

  def test_an_event_before_register_still_raises
    host = AppHost.new { |_page| nil }

    error = assert_raises(RuntimeError) do
      host.handle_message(FakeWs.new([]), pack(:control_event, { "target" => 1, "name" => "click", "data" => "" }))
    end
    assert_equal "Session not found", error.message
    assert_empty host.logged
  end
end
