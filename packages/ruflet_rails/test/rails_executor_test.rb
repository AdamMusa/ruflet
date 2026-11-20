# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"
require "socket"

# The native endpoint runs each client message, and the disconnect, as one
# unit of work in the Rails executor, the way Rails runs an HTTP request and
# Action Cable runs a channel command. It does not hold one executor for the
# whole life of the WebSocket.
#
# Each scenario boots a real Rails app (development reloading, Active Record
# on SQLite) in its own process; see support/rails_executor_app.rb.
class RufletRailsExecutorTest < Minitest::Test
  HARNESS = File.expand_path("support/rails_executor_app.rb", __dir__)
  LIB = File.expand_path("../lib", __dir__)

  def test_editing_app_code_while_a_client_is_connected_does_not_block_requests
    result = run_scenario("reload")

    assert_equal [200, "v1"], result["baseline"]
    assert_equal [200, "v2"], result["request_after_edit"],
                 "the first request after a code edit must not wait for the Ruflet client to disconnect"
    # The connected client keeps working on the reloaded code, and
    # Current.user set by the entrypoint is still set (now on the reloaded
    # Current class, with its new attribute's default).
    assert_equal [2, "ada", "member"], result["click_after_reload"]
  end

  def test_a_handler_reads_rows_another_process_wrote_after_the_first_query
    result = run_scenario("query_cache")

    assert_equal 0, result["before_insert"]
    assert_equal 1, result["after_insert"],
                 "a click handler must not read a query-cache entry from an earlier message"
  end

  def test_a_connected_client_does_not_keep_a_database_connection_leased
    result = run_scenario("connection_lease")

    assert_equal 0, result["request_query"],
                 "a request must get a pooled connection while a Ruflet client stays connected"
  end

  def test_execution_state_the_app_sets_lasts_until_the_client_disconnects
    result = run_scenario("execution_state")

    expected = {
      "user" => "ada", "time_zone" => "Tokyo", "error_context" => "home", "resets" => 0,
      "event_context" => (7 if result["event_reporter"]) # Rails 8.1+
    }
    assert_equal expected.merge("visits" => 1), result["first"]
    assert_equal expected.merge("visits" => 2), result["second"]
    assert_equal 1, result["resets_after_disconnect"], "Current is reset once, when the client disconnects"
  end

  def test_a_handler_error_is_not_reported_as_an_unhandled_rails_error
    result = run_scenario("handler_error")

    assert_equal [], result["reported"]
  end

  # Without a Rails app: a stub executor shows where each run starts and ends.
  def test_each_message_and_the_disconnect_get_their_own_executor_run
    executor = StubExecutor.new
    stub_executor(executor) do
      in_run = Queue.new
      button = nil
      endpoint = Ruflet::Rails.native do |page|
        button = Ruflet::UI::ControlFactory.build(:button, content: "Tap")
        button.on(:click) { |_event| in_run << executor.active? }
        page.add(button)
      end
      server_io, client_io = UNIXSocket.pair
      assert_equal(-1, endpoint.call(hijack_env(server_io)).first)
      client_io.readpartial(1024)
      send_frame(client_io, Ruflet::WireCodec.pack([
        Ruflet::Protocol::ACTIONS[:register_client],
        { "session_id" => "", "page_name" => "", "page" => { "route" => "/" } }
      ]))
      read_frame(client_io) # register reply
      read_frame(client_io) # initial patch
      assert_equal 1, executor.runs, "the registration is one run"
      refute executor.active?, "no run is held while the socket waits for the next message"

      2.times do
        send_frame(client_io, Ruflet::WireCodec.pack([
          Ruflet::Protocol::ACTIONS[:control_event], { "target" => button.wire_id, "name" => "click", "data" => "" }
        ]))
        assert_equal true, in_run.pop(timeout: 5), "the handler runs inside a run"
      end
      client_io.close
      deadline = Time.now + 5
      sleep 0.02 until (executor.runs == 4 && !executor.active?) || Time.now > deadline
      assert_equal 4, executor.runs, "register, two clicks and the disconnect: one run each"
      refute executor.active?
    ensure
      client_io&.close unless client_io&.closed?
    end
  end

  private

  class StubExecutor
    attr_reader :runs

    def initialize
      @runs = 0
      @active = false
    end

    def active?
      @active
    end

    def wrap
      @runs += 1
      @active = true
      yield
    ensure
      @active = false
    end
  end

  def stub_executor(executor)
    execution = Ruflet::Rails::Protocol::Execution
    original = execution.method(:executor)
    execution.define_singleton_method(:executor) { executor }
    yield
  ensure
    execution.define_singleton_method(:executor, original)
  end

  def hijack_env(io)
    {
      "REQUEST_METHOD" => "GET", "PATH_INFO" => "/ws",
      "HTTP_UPGRADE" => "websocket", "HTTP_CONNECTION" => "Upgrade",
      "HTTP_SEC_WEBSOCKET_KEY" => "testkey", "HTTP_SEC_WEBSOCKET_VERSION" => "13",
      "rack.hijack" => -> {}, "rack.hijack_io" => io
    }
  end

  def send_frame(io, payload)
    mask = [1, 2, 3, 4]
    length = payload.bytesize
    header = [0x82].pack("C") + (length < 126 ? [0x80 | length].pack("C") : [0x80 | 126, length].pack("Cn"))
    io.write(header + mask.pack("C4") + payload.bytes.each_with_index.map { |byte, i| byte ^ mask[i % 4] }.pack("C*"))
  end

  def read_frame(io)
    flunk("no frame from the server") unless io.wait_readable(5)
    first = io.read(2)
    length = first.getbyte(1) & 0x7f
    length = io.read(2).unpack1("n") if length == 126
    length = io.read(8).unpack1("Q>") if length == 127
    length.zero? ? "".b : io.read(length)
  end

  def run_scenario(name)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I", LIB, HARNESS, name)
    line = stdout.lines.reverse.find { |entry| entry.start_with?("RUFLET_EXECUTOR_RESULT ") }
    flunk("scenario #{name} printed no result (exit #{status.exitstatus})\n#{stdout}\n#{stderr}") unless line

    result = JSON.parse(line.delete_prefix("RUFLET_EXECUTOR_RESULT "))
    skip(result["skip"]) if result["skip"]
    flunk("scenario #{name}: #{result["error"]}\n#{stderr}") if result["error"]

    result
  end
end
