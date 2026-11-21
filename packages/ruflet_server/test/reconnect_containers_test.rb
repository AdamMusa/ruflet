# frozen_string_literal: true

require_relative "test_helper"

# A client keeps its control tree when it reconnects and its View holds the
# page's _overlay and _dialogs containers it looked up once. Both servers
# must therefore hand a reconnecting client containers it merges into those
# instances: the same wire ids, in the register reply's page_patch, never as
# replace ops.
class ReconnectContainersTest < Minitest::Test
  ACTIONS = Ruflet::Protocol::ACTIONS
  CONTAINER_KEYS = %w[_overlay _services _dialogs].freeze

  # The engine's two ways of applying what a server sends
  # (packages/ruflet/lib/src/models/control.dart): the register reply's
  # page_patch is merged with Control.update, which keeps a control whose
  # _i matches and builds a new one otherwise; a patch_control replace op
  # always builds new controls. Patches reach a control through the id
  # index, which the newest control with that id owns.
  class Client
    Node = Struct.new(:id, :type, :props)

    attr_reader :page

    def initialize
      @page = Node.new(1, "Page", {})
      @index = { 1 => @page }
    end

    def receive(bytes)
      action, payload = Ruflet::WireCodec.unpack(bytes)
      case action
      when ACTIONS[:register_client]
        merge(@page, payload.fetch("page_patch"))
      when ACTIONS[:patch_control]
        node = @index[payload["id"]]
        return unless node

        payload["patch"][1..].each do |op, _node_index, key, value|
          node.props[key] = build(value) if op.zero?
        end
      end
    end

    private

    def merge(node, map)
      map.each do |key, value|
        next if %w[_i _c].include?(key)

        current = node.props[key]
        if current.is_a?(Node) && value.is_a?(Hash) && current.id == value["_i"]
          merge(current, value)
        else
          node.props[key] = build(value)
        end
      end
    end

    def build(value)
      case value
      when Hash
        return value.transform_values { |entry| build(entry) } unless value.key?("_c")

        node = Node.new(value["_i"], value["_c"], {})
        @index[node.id] = node
        value.each { |key, entry| node.props[key] = build(entry) unless %w[_i _c].include?(key) }
        node
      when Array
        value.map { |entry| build(entry) }
      else
        value
      end
    end
  end

  class FakeWs
    attr_reader :sent

    def initialize(key, client)
      @key = key
      @client = client
      @sent = []
    end

    def session_key = @key
    def closed? = false
    def close; end

    def send_binary(bytes)
      @sent << Ruflet::WireCodec.unpack(bytes)
      @client.receive(bytes)
    end
  end

  # ruflet_rails' LocalServer: ConnectionProtocol plus a session registry,
  # so a client that re-registers while its Page is held resumes it.
  class Host
    include Ruflet::ConnectionProtocol

    attr_reader :pages

    def initialize(resume: false, &app)
      @app_block = app
      @resume = resume
      @sessions = {}
      @sessions_mutex = Mutex.new
      @pages = {}
    end

    def resume_session(session_id)
      @resume ? @pages[session_id] : nil
    end

    def session_stored(page, _ws)
      @pages[page.session_id] = page
    end

    def page_for(ws)
      @sessions_mutex.synchronize { @sessions[ws.session_key] }
    end
  end

  class ServerProbe < Ruflet::Server
    public :handle_message

    def page_for(ws)
      @sessions_mutex.synchronize { @sessions[ws.session_key] }
    end
  end

  # One row on "/", six elsewhere: the content registered before the
  # containers depends on the route.
  APP = lambda do |page|
    rows = page.route == "/" ? 1 : 6
    page.add(Ruflet.column(controls: Array.new(rows) { |i| Ruflet.text("row #{i}") }))
  end

  def register(server, ws, route)
    server.handle_message(ws, Ruflet::WireCodec.pack([
      ACTIONS[:register_client],
      { "session_id" => "same-session", "page_name" => "", "page" => { "route" => route } }
    ]))
  end

  def shown_dialog_titles(container)
    container.props.fetch("controls").map { |dialog| dialog.props["title"].props["value"] }
  end

  # Connects, reconnects through +second_server+ (a fresh or resumed Page),
  # then shows a dialog from the second Page. Returns the dialogs container
  # the client's View captured before the reconnect.
  def reconnect_and_show_dialog(first_server, second_server, first_route:, second_route:)
    client = Client.new
    first_ws = FakeWs.new(1, client)
    register(first_server, first_ws, first_route)
    view_dialogs = client.page.props.fetch("_dialogs")
    view_overlay = client.page.props.fetch("_overlay")

    second_ws = FakeWs.new(2, client)
    register(second_server, second_ws, second_route)
    second_server.page_for(second_ws).show_dialog(Ruflet.alert_dialog(title: Ruflet.text("After reconnect")))

    [view_dialogs, view_overlay, client, second_ws]
  end

  def test_rails_reconnect_with_a_fresh_page_keeps_the_clients_containers
    first = Host.new(&APP)
    second = Host.new(&APP)

    view_dialogs, view_overlay, client, = reconnect_and_show_dialog(first, second, first_route: "/", second_route: "/settings")

    assert_same view_dialogs, client.page.props["_dialogs"], "the View's dialogs container must stay the client's"
    assert_same view_overlay, client.page.props["_overlay"]
    assert_equal ["After reconnect"], shown_dialog_titles(view_dialogs)
  end

  def test_rails_reconnect_that_resumes_the_page_keeps_the_clients_containers
    host = Host.new(resume: true, &APP)

    view_dialogs, view_overlay, client, = reconnect_and_show_dialog(host, host, first_route: "/", second_route: "/")

    assert_same view_dialogs, client.page.props["_dialogs"]
    assert_same view_overlay, client.page.props["_overlay"]
    assert_equal ["After reconnect"], shown_dialog_titles(view_dialogs)
  end

  def test_ruflet_run_reconnect_on_a_route_with_more_content_keeps_the_clients_containers
    view_dialogs, view_overlay, client, = reconnect_and_show_dialog(
      ServerProbe.new(port: 0, &APP), ServerProbe.new(port: 0, &APP),
      first_route: "/", second_route: "/settings"
    )

    assert_same view_dialogs, client.page.props["_dialogs"]
    assert_same view_overlay, client.page.props["_overlay"]
    assert_equal ["After reconnect"], shown_dialog_titles(view_dialogs)
  end

  def test_rails_register_reply_carries_the_containers_and_no_patch_replaces_them
    ws = FakeWs.new(1, Client.new)

    register(Host.new(&APP), ws, "/")

    action, reply = ws.sent.first
    assert_equal ACTIONS[:register_client], action
    assert_equal({ "_overlay" => 3, "_services" => 4, "_dialogs" => 5 },
                 reply["page_patch"].transform_values { |container| container["_i"] })
    patches = ws.sent.drop(1)
    refute_empty patches
    patches.each do |_action, payload|
      assert_empty payload["patch"][1..].map { |op| op[2] } & CONTAINER_KEYS
    end
  end

  # The register reply still goes out before the app block runs, and what
  # the block renders streams as it renders.
  def test_rails_first_paint_stays_progressive
    sent_while_rendering = nil
    ws = nil
    host = Host.new do |page|
      page.add(Ruflet.progress_ring)
      sent_while_rendering = ws.sent.map(&:first)
      page.add(Ruflet.text("Loaded"))
    end
    ws = FakeWs.new(1, Client.new)

    register(host, ws, "/")

    assert_equal [ACTIONS[:register_client], ACTIONS[:patch_control]], sent_while_rendering
    assert_equal [ACTIONS[:register_client], ACTIONS[:patch_control], ACTIONS[:patch_control]], ws.sent.map(&:first)
  end
end
