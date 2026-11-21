# frozen_string_literal: true

require_relative "test_helper"
require "socket"
require "stringio"

# A client that presents a registered session id resumes that session's
# Page (Flet's reconnect). It must not get the Page of a client that is still
# connected: a duplicated browser tab copies sessionStorage, so it registers
# with the first tab's id while that tab is open, and a socket that learned
# a live id would get another user's page and handlers (AdamMusa/ruflet#114).
#
# Every test runs the real Rack endpoint over hijacked socket pairs. Clients
# answer pings the way browsers and dart:io do, unless a test plays a
# dropped connection the server has not noticed yet.
class RufletRailsSessionResumeTest < Minitest::Test
  ACTIONS = Ruflet::Protocol::ACTIONS

  # The client side of one WebSocket: a reader thread decodes binary frames
  # into a queue and, like a browser, answers every ping. closes_on_ping
  # plays a connection that died without the server noticing, whose peer
  # resets (or whose proxy closes the upstream) once the server writes to it.
  class Client
    attr_reader :session_id, :pings

    def initialize(endpoint, cookie: nil, answers_pings: true, closes_on_ping: false)
      @server_io, @io = UNIXSocket.pair
      @answers_pings = answers_pings
      @closes_on_ping = closes_on_ping
      @pings = 0
      @messages = Queue.new
      @write_mutex = Mutex.new
      env = {
        "REQUEST_METHOD" => "GET", "PATH_INFO" => "/ws", "HTTP_UPGRADE" => "websocket",
        "HTTP_CONNECTION" => "Upgrade", "HTTP_SEC_WEBSOCKET_KEY" => "testkey",
        "HTTP_SEC_WEBSOCKET_VERSION" => "13", "rack.hijack" => -> {}, "rack.hijack_io" => @server_io
      }
      env["HTTP_COOKIE"] = cookie if cookie
      status, = endpoint.call(env)
      raise "endpoint did not hijack the socket (#{status})" unless status == -1

      response = +""
      response << @io.readpartial(1024) until response.include?("\r\n\r\n")
      @reader = Thread.new { read_loop }
    end

    def register(session_id)
      send_message(ACTIONS[:register_client], {
        "session_id" => session_id, "page_name" => "",
        "page" => { "route" => "/", "width" => 400, "height" => 800, "platform" => "ios" }
      })
      ack = next_message
      raise "no register reply" unless ack && ack[0] == ACTIONS[:register_client]

      @session_id = ack[1]["session_id"]
    end

    def click(wire_id)
      send_message(ACTIONS[:control_event], { "target" => wire_id, "name" => "click", "data" => "" })
    end

    def next_message(timeout = 3)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        return @messages.pop(true)
      rescue ThreadError
        return nil if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end
    end

    # Reads until a message whose text includes +text+ (the page patch
    # carrying a known control) and returns every message read on the way.
    def read_until(text, timeout = 5)
      out = []
      while (message = next_message(timeout))
        out << message
        break if message.inspect.include?(text)
      end
      out
    end

    def close
      @io.close unless @io.closed?
      @reader.join(1)
    end

    def server_closed?
      @server_io.closed?
    end

    private

    def send_message(action, payload)
      write_frame(0x2, Ruflet::WireCodec.pack([action, payload]))
    end

    def write_frame(opcode, payload)
      mask = Array.new(4) { rand(256) }
      length = payload.bytesize
      header = [0x80 | opcode].pack("C") +
               (length < 126 ? [0x80 | length].pack("C") : [0x80 | 126, length].pack("Cn"))
      masked = payload.bytes.each_with_index.map { |byte, index| byte ^ mask[index % 4] }.pack("C*")
      @write_mutex.synchronize { @io.write(header + mask.pack("C4") + masked) }
    end

    def read_loop
      loop do
        head = @io.read(2)
        break unless head && head.bytesize == 2

        opcode = head.getbyte(0) & 0x0f
        length = head.getbyte(1) & 0x7f
        length = @io.read(2).unpack1("n") if length == 126
        length = @io.read(8).unpack1("Q>") if length == 127
        payload = length.zero? ? "".b : @io.read(length)
        case opcode
        when 0x2 then @messages << Ruflet::WireCodec.unpack(payload)
        when 0x9
          @pings += 1
          if @closes_on_ping
            @io.close
            break
          end
          write_frame(0xA, payload) if @answers_pings
        when 0x8 then break
        end
      end
    rescue IOError, SystemCallError
      nil
    end
  end

  def setup
    Ruflet::Rails.sessions.clear
    @config = Ruflet::Rails.config
    @saved_config = [@config.session_resume_probe_timeout, @config.session_resume_guard]
    @clients = []
    @actions = Queue.new
  end

  def teardown
    @clients.each(&:close)
    @config.session_resume_probe_timeout, @config.session_resume_guard = @saved_config
    Ruflet::Rails.sessions.clear
  end

  # The repro from #114: the app reads its user from the request, as Rails
  # apps do, and builds handlers that act as that user.
  def bank_endpoint
    actions = @actions
    Ruflet::Rails::Protocol::Runner.new do |page, env|
      user = env["HTTP_COOKIE"].to_s[/user=(\w+)/, 1]
      button = Ruflet::UI::ControlFactory.build(:button, content: "Transfer")
      button.on(:click) { |_event| actions << "transfer as #{user.inspect}" }
      page.add(Ruflet::UI::ControlFactory.build(:text, value: "Balance of #{user.inspect}: $1,234"))
      page.add(button)
    end.build_endpoint(path: "/ws")
  end

  def client(endpoint, **options)
    Client.new(endpoint, **options).tap { |c| @clients << c }
  end

  def wire_id(messages, text)
    messages.each do |(_action, payload)|
      found = find_wire_id(payload, text)
      return found if found
    end
    nil
  end

  def find_wire_id(node, text)
    case node
    when Hash
      return node["_i"] if node.values.any? { |value| value.to_s == text }

      node.each_value { |value| (found = find_wire_id(value, text)) and return found }
      nil
    when Array
      node.each { |value| (found = find_wire_id(value, text)) and return found }
      nil
    end
  end

  def counter_endpoint
    Ruflet::Rails::Protocol::Runner.new do |page|
      count = 0
      label = Ruflet::UI::ControlFactory.build(:text, value: "count 0")
      button = Ruflet::UI::ControlFactory.build(:button, content: "+1")
      button.on(:click) do |_event|
        count += 1
        page.update(label, value: "count #{count}")
      end
      page.add(label)
      page.add(button)
    end.build_endpoint(path: "/ws")
  end

  def next_action(timeout = 3)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return @actions.pop(true)
    rescue ThreadError
      return nil if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end
  end

  def test_a_socket_presenting_a_live_session_id_gets_its_own_session
    endpoint = bank_endpoint
    victim = client(endpoint, cookie: "user=alice")
    victim_id = victim.register("")
    victim_page = victim.read_until("Transfer")
    assert_includes victim_page.inspect, 'Balance of \"alice\"'

    attacker = client(endpoint)
    attacker_id = attacker.register(victim_id)
    attacker_page = attacker.read_until("Transfer")

    refute_equal victim_id, attacker_id, "the second socket must get a new session id"
    assert_match(/\A\h{8}-\h{4}-4\h{3}-[89ab]\h{3}-\h{12}\z/, attacker_id)
    refute_includes attacker_page.inspect, "alice", "the second socket must not receive the first client's page"
    assert_includes attacker_page.inspect, "Balance of nil"
    assert_equal 1, victim.pings, "the owner is pinged once"

    attacker.click(wire_id(attacker_page, "Transfer"))
    assert_equal "transfer as nil", next_action, "the second socket runs its own handlers"

    victim.click(wire_id(victim_page, "Transfer"))
    assert_equal 'transfer as "alice"', next_action, "the first client keeps its session"

    assert_equal 2, Ruflet::Rails.sessions.size
    assert_equal "user=alice", Ruflet::Rails.sessions[victim_id].env["HTTP_COOKIE"]
    assert_nil Ruflet::Rails.sessions[attacker_id].env["HTTP_COOKIE"]
  end

  # Browsers copy sessionStorage (and the Ruflet session id in it) into a
  # duplicated tab or a window.open window.
  def test_a_duplicated_tab_gets_its_own_page_and_closing_it_keeps_the_original
    endpoint = counter_endpoint
    tab1 = client(endpoint)
    tab1_id = tab1.register(nil)
    tab1_button = wire_id(tab1.read_until("+1"), "+1")
    tab2 = client(endpoint)
    tab2_id = tab2.register(tab1_id)
    tab2_button = wire_id(tab2.read_until("+1"), "+1")

    refute_equal tab1_id, tab2_id
    assert_equal 2, Ruflet::Rails.sessions.size

    tab2.click(tab2_button)
    assert_includes tab2.read_until("count 1").inspect, "count 1"
    tab1.click(tab1_button)
    assert_includes tab1.read_until("count 1").inspect, "count 1", "each tab counts on its own page"

    assert_equal 2, Ruflet::Rails.broadcast { |page| page.title = "pushed" }

    tab2.close
    deadline = Time.now + 3
    sleep 0.02 until Ruflet::Rails.sessions[tab2_id].nil? || Time.now > deadline
    assert_nil Ruflet::Rails.sessions[tab2_id]
    refute_nil Ruflet::Rails.sessions[tab1_id], "closing the duplicate must not drop the original tab's session"
  end

  # The reconnect race the resume exists for: the client's old connection
  # died without the server noticing, so its socket is still open on the
  # server but nothing answers on it.
  def test_a_reconnect_over_a_dead_socket_still_resumes_the_page
    @config.session_resume_probe_timeout = 0.2
    endpoint = bank_endpoint
    dropped = client(endpoint, cookie: "user=alice", answers_pings: false)
    session_id = dropped.register("")
    dropped.read_until("Transfer")

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    reconnect = client(endpoint, cookie: "user=alice")
    resumed_id = reconnect.register(session_id)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    page = reconnect.read_until("Transfer")

    assert_equal session_id, resumed_id, "the reconnecting client resumes its session"
    assert_operator elapsed, :>=, 0.2, "the server waited for the old socket's pong"
    assert_equal 1, dropped.pings
    assert_includes page.inspect, 'Balance of \"alice\"'
    reconnect.click(wire_id(page, "Transfer"))
    assert_equal 'transfer as "alice"', next_action
    assert_equal 1, Ruflet::Rails.sessions.size
  end

  # The old socket closes while it is pinged, and its close removes the
  # session from the registry before the probe returns. The reconnecting
  # client still resumes the Page it had, with its state.
  def test_a_reconnect_whose_old_socket_closes_on_the_ping_still_resumes_the_page
    # Long enough that the probe returns because the old socket closed,
    # not because it timed out.
    @config.session_resume_probe_timeout = 10
    endpoint = counter_endpoint
    old = client(endpoint, closes_on_ping: true)
    session_id = old.register(nil)
    button = wire_id(old.read_until("+1"), "+1")
    old.click(button)
    old.read_until("count 1")
    old.click(button)
    old.read_until("count 2")

    reconnect = client(endpoint)
    resumed_id = reconnect.register(session_id)
    page = reconnect.read_until("+1")

    assert_equal 1, old.pings
    assert_equal session_id, resumed_id, "the reconnecting client keeps its session id"
    assert_includes page.inspect, "count 2", "the reconnecting client resumes its Page"
    reconnect.click(wire_id(page, "+1"))
    assert_includes reconnect.read_until("count 3").inspect, "count 3"
    assert_equal 1, Ruflet::Rails.sessions.size
    refute_nil Ruflet::Rails.sessions[session_id]
  end

  # A client that registers again on its own socket owns the session: the
  # server must not ping that socket, whose pong only the thread doing the
  # register could read.
  def test_registering_again_on_the_same_socket_resumes_without_a_ping
    @config.session_resume_probe_timeout = 0.5
    endpoint = counter_endpoint
    tab = client(endpoint)
    session_id = tab.register(nil)
    tab.read_until("+1")

    assert_equal session_id, tab.register(session_id)
    assert_equal 0, tab.pings
    assert_equal 1, Ruflet::Rails.sessions.size
  end

  # An owner socket whose ping would say a live client holds the session.
  class AnsweringSocket
    attr_reader :pings

    def initialize(closed: false)
      @closed = closed
      @pings = 0
    end

    def closed?
      @closed
    end

    def session_key
      object_id
    end

    def ping(timeout:)
      @pings += 1
      true
    end
  end

  def test_a_closed_owner_or_the_registering_socket_itself_is_never_pinged
    registry = Ruflet::Rails::SessionRegistry.new
    server = Ruflet::Rails::Protocol::LocalServer.new(session_registry: registry) { |_page| }
    closed_owner = AnsweringSocket.new(closed: true)
    registry.add(key: "closed", page: :closed_page, connection_key: closed_owner.session_key, connection: closed_owner)
    owner = AnsweringSocket.new
    registry.add(key: "own", page: :own_page, connection_key: owner.session_key, connection: owner)

    assert server.allow_resume?("closed", AnsweringSocket.new), "a closed owner is a dropped connection"
    assert_equal 0, closed_owner.pings
    assert server.allow_resume?("own", owner), "a socket may resume the session it owns"
    assert_equal 0, owner.pings
    assert_equal :own_page, server.resume_session("own")
  end

  def test_a_closed_owner_is_not_pinged
    endpoint = bank_endpoint
    first = client(endpoint, cookie: "user=alice")
    session_id = first.register("")
    first.read_until("Transfer")
    first.close
    deadline = Time.now + 3
    sleep 0.02 until Ruflet::Rails.sessions[session_id].nil? || Time.now > deadline

    second = client(endpoint, cookie: "user=alice")

    assert_equal session_id, second.register(session_id), "an id the registry dropped is kept, as before"
    assert_equal 0, first.pings
  end

  def test_session_resume_guard_can_refuse_a_resume
    @config.session_resume_probe_timeout = 0.2
    seen = []
    @config.session_resume_guard = lambda do |original_env, new_env|
      seen << [original_env["HTTP_COOKIE"], new_env["HTTP_COOKIE"]]
      original_env["HTTP_COOKIE"] == new_env["HTTP_COOKIE"]
    end
    endpoint = bank_endpoint
    dropped = client(endpoint, cookie: "user=alice", answers_pings: false)
    session_id = dropped.register("")
    dropped.read_until("Transfer")

    stranger = client(endpoint, cookie: "user=mallory")
    stranger_id = stranger.register(session_id)
    stranger_page = stranger.read_until("Transfer")
    pings_after_refusal = dropped.pings
    owner = client(endpoint, cookie: "user=alice")
    owner_id = owner.register(session_id)

    refute_equal session_id, stranger_id, "the guard refused the resume"
    refute_includes stranger_page.inspect, "alice"
    assert_equal 0, pings_after_refusal, "a refused resume does not ping the owner"
    assert_equal session_id, owner_id, "the guard allowed the owner's reconnect"
    assert_equal [["user=alice", "user=mallory"], ["user=alice", "user=alice"]], seen
  end

  def test_a_raising_guard_refuses_the_resume
    @config.session_resume_probe_timeout = 0.2
    @config.session_resume_guard = ->(_original_env, _new_env) { raise "guard failed" }
    endpoint = bank_endpoint
    dropped = client(endpoint, cookie: "user=alice", answers_pings: false)
    session_id = dropped.register("")
    dropped.read_until("Transfer")

    original_stderr = $stderr
    $stderr = StringIO.new
    other_id = client(endpoint, cookie: "user=alice").register(session_id)
    log = $stderr.string
    $stderr = original_stderr

    refute_equal session_id, other_id
    assert_includes log, "guard failed"
  ensure
    $stderr = original_stderr if original_stderr
  end

  # session_resume_probe_timeout = nil skips the ping: a second socket then
  # resumes the session even while its owner is connected, as before.
  def test_disabling_the_probe_keeps_the_previous_resume
    @config.session_resume_probe_timeout = nil
    endpoint = bank_endpoint
    first = client(endpoint, cookie: "user=alice")
    session_id = first.register("")
    first.read_until("Transfer")

    second = client(endpoint)

    assert_equal session_id, second.register(session_id)
    assert_includes second.read_until("Transfer").inspect, 'Balance of \"alice\"'
    assert_equal 0, first.pings
  end
end
