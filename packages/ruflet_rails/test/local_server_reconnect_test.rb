# frozen_string_literal: true

require_relative "test_helper"

# A native client keeps its control tree across a reconnect, and its View
# holds the page's _overlay and _dialogs containers it looked up once. The
# Rails endpoint must hand it containers it merges into those instances: in
# the register reply, under the same wire ids, never as replace ops.
class RufletRailsLocalServerReconnectTest < Minitest::Test
  CONTAINER_KEYS = %w[_overlay _services _dialogs].freeze

  class Socket
    attr_reader :sent

    def initialize(key)
      @key = key
      @sent = []
    end

    def session_key = @key
    def closed? = false
    def close; end
    def send_binary(bytes) = @sent << Ruflet::WireCodec.unpack(bytes)
  end

  def setup
    @registry = Ruflet::Rails::SessionRegistry.new
    @server = Ruflet::Rails::Protocol::LocalServer.new(session_registry: @registry) do |page|
      rows = page.route == "/" ? 1 : 6
      page.add(Ruflet.column(controls: Array.new(rows) { |i| Ruflet.text("row #{i}") }))
    end
  end

  def register(ws, route)
    @server.send(:on_register_client, ws, { "session_id" => "native-session", "page" => { "route" => route } })
  end

  def container_ids(ws)
    reply = ws.sent.first[1]
    reply.fetch("page_patch").slice(*CONTAINER_KEYS).transform_values { |container| container["_i"] }
  end

  def replaced_keys(ws)
    ws.sent.drop(1).flat_map { |_action, payload| payload["patch"][1..].map { |op| op[2] } } & CONTAINER_KEYS
  end

  # Native clients send no session id they can resume (the engine's
  # non-web session store returns null), so every reconnect is a fresh Page,
  # here on a route that registers more controls first.
  def test_a_fresh_page_after_the_old_socket_closed_names_the_same_containers
    first = Socket.new("socket-1")
    register(first, "/")
    @server.send(:remove_session, first)
    assert_nil @registry["native-session"]

    second = Socket.new("socket-2")
    register(second, "/settings")

    expected = { "_overlay" => 3, "_services" => 4, "_dialogs" => 5 }
    assert_equal expected, container_ids(first)
    assert_equal expected, container_ids(second)
    assert_empty replaced_keys(first)
    assert_empty replaced_keys(second)
  end

  def test_a_dialog_shown_after_a_fresh_reconnect_patches_the_same_container
    first = Socket.new("socket-1")
    register(first, "/")
    @server.send(:remove_session, first)
    second = Socket.new("socket-2")
    register(second, "/settings")
    second.sent.clear

    @registry["native-session"].page.show_dialog(Ruflet.alert_dialog(title: Ruflet.text("After reconnect")))

    assert_equal [5], second.sent.map { |_action, payload| payload["id"] }
  end
end
