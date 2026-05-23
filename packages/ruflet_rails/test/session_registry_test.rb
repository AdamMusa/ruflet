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
      server.send(:on_register_client, ws, { "page" => { "route" => "/orders" } })
    end

    session = registry[ws.session_key]

    refute_nil session
    assert_equal env, session.env
    assert_equal "/orders", session.page.route
    assert_equal 2, ws.sent.length
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

    def initialize
      @sent = []
    end

    def session_key
      "fake-socket"
    end

    def send_binary(payload)
      @sent << payload
    end
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
