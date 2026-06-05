# frozen_string_literal: true

require_relative "test_helper"

class RufletRailsSessionRegistryTest < Minitest::Test
  def setup
    Ruflet::Rails.sessions.clear
  end

  def teardown
    Ruflet::Rails.sessions.clear
  end

  def test_registry_tracks_sessions_and_broadcasts_to_pages
    page = FakePage.new(session_id: "session-1", client_details: { "route" => "/" })

    session = Ruflet::Rails.sessions.add(key: "socket-1", page: page, env: { "PATH_INFO" => "/ws" })

    assert_equal session, Ruflet::Rails.sessions["socket-1"]
    assert_equal "session-1", session.session_id
    assert_equal({ "route" => "/" }, session.client_details)
    assert_equal 1, Ruflet::Rails.broadcast { |connected_page| connected_page.title = "Updated" }
    assert_equal "Updated", page.title
  end

  def test_broadcast_can_filter_with_plain_ruby
    first = FakePage.new(session_id: "session-1", client_details: { "route" => "/" })
    second = FakePage.new(session_id: "session-2", client_details: { "route" => "/settings" })
    third = FakePage.new(session_id: "session-3", client_details: { "route" => "/gallery" })

    Ruflet::Rails.sessions.add(key: "socket-1", page: first)
    Ruflet::Rails.sessions.add(key: "socket-2", page: second)
    Ruflet::Rails.sessions.add(key: "socket-3", page: third)

    assert_equal 3, Ruflet::Rails.broadcast { |page, session|
      next unless session.client_details["route"] == "/settings"

      page.title = "Filtered"
    }
    assert_nil first.title
    assert_equal "Filtered", second.title
    assert_nil third.title
  end

  def test_broadcast_blocks_can_use_global_ruflet_builders
    page = FakePage.new(session_id: "session-1", client_details: { "route" => "/" })
    Ruflet::Rails.sessions.add(key: "socket-1", page: page)

    Ruflet::Rails.broadcast do |connected_page|
      connected_page.snack_bar = snack_bar(text("Saved"))
    end

    assert_equal "SnackBar", page.snack_bar.to_patch["_c"]
    assert_equal "Text", page.snack_bar.to_patch["content"]["_c"]
    assert_equal "Saved", page.snack_bar.to_patch["content"]["value"]
  end

  def test_local_server_adds_registered_pages_to_registry_with_env
    registry = Ruflet::Rails::SessionRegistry.new
    server = Ruflet::Rails::Protocol::LocalServer.new(session_registry: registry) { |_page| }
    ws = FakeWebSocket.new
    env = { "PATH_INFO" => "/ws" }

    Ruflet::Rails::Protocol::Context.with_env(env) do
      server.send(:on_register_client, ws, { "session_id" => "fake-session", "page" => { "route" => "/orders" } })
    end

    session = registry["fake-session"]

    refute_nil session
    assert_equal env, session.env
    assert_equal "/orders", session.page.route
    assert_equal 2, ws.sent.length
  end

  def test_local_server_reattaches_existing_page_when_websocket_reconnects
    registry = Ruflet::Rails::SessionRegistry.new
    renders = 0
    server = Ruflet::Rails::Protocol::LocalServer.new(session_registry: registry) do |page|
      renders += 1
      page.title = "Rendered"
    end
    first_ws = FakeWebSocket.new("socket-1")
    second_ws = FakeWebSocket.new("socket-2")

    server.send(:on_register_client, first_ws, { "session_id" => "same-session", "page" => { "route" => "/posts" } })
    first_page = registry["same-session"].page
    first_page.show_dialog(Ruflet.alert_dialog(title: Ruflet.text("Still open")))

    server.send(:on_register_client, second_ws, { "session_id" => "same-session", "page" => { "route" => "/posts" } })
    second_session = registry["same-session"]
    second_messages = second_ws.sent.map { |payload| Ruflet::Rails::Protocol::WireCodec.unpack(payload) }
    reattach_patch = second_messages.last[1]["patch"]

    assert_same first_page, second_session.page
    assert_equal "socket-2", second_session.connection_key
    assert_equal 1, renders
    assert reattach_patch.any? { |op| op[2] == "_dialogs" },
           "reattached clients must receive the current dialog container ids"

    server.send(:remove_session, first_ws)

    assert_same first_page, registry["same-session"].page

    server.send(:remove_session, second_ws)

    assert_nil registry["same-session"]
  end

  def test_local_server_replies_to_the_socket_that_sent_an_event
    registry = Ruflet::Rails::SessionRegistry.new
    label = nil
    button = nil
    server = Ruflet::Rails::Protocol::LocalServer.new(session_registry: registry) do |page|
      label = Ruflet.text("Before")
      button = Ruflet.text_button("Change", on_click: ->(_event) { page.update(label, value: "After") })
      page.add(label, button)
    end
    first_ws = FakeWebSocket.new("socket-1")
    second_ws = FakeWebSocket.new("socket-2")

    server.send(:on_register_client, first_ws, { "session_id" => "same-session", "page" => { "route" => "/posts" } })
    server.send(:on_register_client, second_ws, { "session_id" => "same-session", "page" => { "route" => "/posts" } })
    first_ws.sent.clear
    second_ws.sent.clear

    server.send(:on_control_event, first_ws, { "target" => button.wire_id, "name" => "click" })

    first_messages = first_ws.sent.map { |payload| Ruflet::Rails::Protocol::WireCodec.unpack(payload) }

    assert first_messages.any? { |(_action, payload)| payload["id"] == label.wire_id },
           "event responses must be sent to the socket that emitted the event"
    assert_empty second_ws.sent
  end

  def test_endpoint_uses_rails_executor_when_available
    wrapped = false
    fake_rails = Class.new do
      define_singleton_method(:application) do
        Struct.new(:executor).new(
          Class.new do
            define_method(:wrap) do |&block|
              block.call
              :wrapped
            end
          end.new
        )
      end
    end
    Object.const_set(:Rails, fake_rails)

    endpoint = Ruflet::Rails::Protocol::Endpoint.new(server: Object.new)
    result = endpoint.send(:rails_executor_wrap) { wrapped = true }

    assert wrapped
    assert_equal :wrapped, result
  ensure
    Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails) && Object.const_get(:Rails) == fake_rails
  end

  class FakeWebSocket
    attr_reader :sent

    def initialize(session_key = "fake-socket")
      @sent = []
      @session_key = session_key
    end

    def session_key
      @session_key
    end

    def session_id
      "fake-session"
    end

    def send_binary(payload)
      @sent << payload
    end

    def closed?
      false
    end

    def close; end
  end

  class FakePage
    attr_accessor :title, :snack_bar
    attr_reader :session_id, :client_details

    def initialize(session_id:, client_details:)
      @session_id = session_id
      @client_details = client_details
    end
  end
end
