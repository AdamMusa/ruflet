# frozen_string_literal: true

require_relative "test_helper"

# Every Protocol action, through both message receivers: Ruflet::Server (the
# standalone server `ruflet run` starts) and Ruflet::ConnectionProtocol (the
# loop host adapters such as ruflet_rails include). A client must get the
# same result from either, legacy JSON spellings included.
class ProtocolActionContractTest < Minitest::Test
  ACTIONS = Ruflet::Protocol::ACTIONS
  KINDS = %i[server connection_protocol].freeze

  # [kind, action] for every test defined with `contract` below.
  COVERED = []

  # Defines a test of `action` on the `kind` receiver and records it, so
  # test_every_action_has_a_test_on_both_receivers sees which actions have one.
  def self.contract(kind, action, description, &body)
    COVERED << [kind, action]
    define_method("test_#{kind}_#{description}", &body)
  end

  class FakeWs
    attr_reader :sent

    def initialize
      @sent = []
    end

    def session_key = object_id
    def closed? = false
    def close; end

    def send_binary(bytes)
      @sent << bytes
    end

    def frames
      @sent.map { |bytes| Ruflet::WireCodec.unpack(bytes) }
    end
  end

  class ProtocolHost
    include Ruflet::ConnectionProtocol

    def initialize(&app)
      @app_block = app
      @sessions = {}
      @sessions_mutex = Mutex.new
    end
  end

  # One client connection to a receiver.
  class Harness
    attr_reader :ws, :clicks, :replies

    def initialize(kind, &app)
      @ws = FakeWs.new
      @clicks = []
      @replies = []
      app ||= method(:default_app)
      @receiver =
        if kind == :server
          Ruflet::Server.new(port: 0, &app).tap do |server|
            server.instance_variable_get(:@connections)[@ws.session_key] = @ws
          end
        else
          ProtocolHost.new(&app)
        end
    end

    def receive(action, payload)
      @receiver.send(:handle_message, @ws, Ruflet::WireCodec.pack([action, payload]))
    end

    def register(action = ACTIONS[:register_client])
      receive(action, { "session_id" => "s1", "page" => { "route" => "/start", "width" => 400 } })
    end

    def page
      @receiver.instance_variable_get(:@sessions)[@ws.session_key]
    end

    def button = page.controls[0]
    def field = page.controls[1]

    private

    def default_app(page)
      clicks = @clicks
      page.add(Ruflet.button("Go", on_click: ->(event) { clicks << event }))
      page.add(Ruflet.text_field(value: "start"))
    end
  end

  def test_every_action_has_a_test_on_both_receivers
    KINDS.each do |kind|
      covered = COVERED.select { |covered_kind, _| covered_kind == kind }.map(&:last).uniq
      assert_equal ACTIONS.keys.sort, covered.sort, "#{kind} has no contract test for some action"
    end
  end

  # Waits for the invoke_control_method request the page sent and returns its
  # call id. invoke_sync sends it from its own thread.
  def sent_invoke_call_id(client)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    loop do
      request = client.ws.sent.dup.map { |bytes| Ruflet::WireCodec.unpack(bytes) }
                      .find { |action, _| action == ACTIONS[:invoke_control_method] }
      return request[1]["call_id"] if request
      flunk "the page sent no invoke_control_method request" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.01
    end
  end

  def invoke_sync_in_thread(client)
    Thread.new { client.page.invoke_sync(client.button, "focus", timeout: 10) }.tap do |thread|
      thread.report_on_exception = false
    end
  end

  KINDS.each do |kind|
    %i[register_client register_web_client].each do |action|
      contract(kind, action, "#{action}_creates_the_page_and_answers") do
        client = Harness.new(kind)
        client.register(ACTIONS.fetch(action))

        reply_action, reply = client.ws.frames.first
        assert_equal ACTIONS[:register_client], reply_action
        assert_equal "s1", reply["session_id"]
        assert_equal "", reply["error"]
        assert_equal "/start", client.page.route
        assert_equal 400, client.page.client_details["width"]
        refute_nil client.button.wire_id, "the app block ran and its controls were published"
      end
    end

    %i[control_event page_event_from_web].each do |action|
      contract(kind, action, "#{action}_runs_the_controls_handler") do
        client = Harness.new(kind)
        client.register

        client.receive(ACTIONS.fetch(action), { "target" => client.button.wire_id, "name" => "click", "data" => { "x" => 1 } })
        client.receive(ACTIONS.fetch(action), { "eventTarget" => client.button.wire_id, "eventName" => "click" })

        assert_equal 2, client.clicks.size
        assert_same client.button, client.clicks.first.control
        assert_equal({ x: 1 }, client.clicks.first.data)
      end
    end

    %i[update_control update_control_props].each do |action|
      contract(kind, action, "#{action}_applies_the_clients_props") do
        client = Harness.new(kind)
        client.register

        client.receive(ACTIONS.fetch(action), { "id" => client.field.wire_id, "props" => { "value" => "typed" } })

        assert_equal "typed", client.field.props["value"]
      end
    end

    contract(kind, :invoke_control_method, "invoke_control_method_reply_reaches_on_result") do
      client = Harness.new(kind)
      client.register
      replies = client.replies
      on_result = ->(result, error) { replies << [result, error] }

      # The engine's reply (InvokeMethodResponseBody#toMap): control_id,
      # call_id, result, error.
      first = client.page.invoke(client.button, "focus", on_result: on_result)
      client.receive(ACTIONS[:invoke_control_method], { "control_id" => client.button.wire_id, "call_id" => first, "result" => "done", "error" => nil })

      # The engine's reply when the call failed.
      failed = client.page.invoke(client.button, "focus", on_result: on_result)
      error = "Calling focus method of inexistent control: #{client.button.wire_id}"
      client.receive(ACTIONS[:invoke_control_method], { "control_id" => client.button.wire_id, "call_id" => failed, "result" => nil, "error" => error })

      # No shipped client sends callId/value, but Protocol's normalizer
      # accepts that spelling, so both receivers must deliver it alike.
      second = client.page.invoke(client.button, "focus", on_result: on_result)
      client.receive(ACTIONS[:invoke_control_method], { "callId" => second, "value" => "legacy" })

      assert_equal [["done", nil], [nil, error], ["legacy", nil]], replies
    end

    contract(kind, :invoke_control_method, "invoke_sync_returns_the_reply_result") do
      client = Harness.new(kind)
      client.register
      client.ws.sent.clear

      waiting = invoke_sync_in_thread(client)
      call_id = sent_invoke_call_id(client)
      client.receive(ACTIONS[:invoke_control_method], { "control_id" => client.button.wire_id, "call_id" => call_id, "result" => 5, "error" => nil })

      assert_equal 5, waiting.value
    end

    contract(kind, :invoke_control_method, "invoke_sync_raises_the_reply_error") do
      client = Harness.new(kind)
      client.register
      client.ws.sent.clear

      waiting = invoke_sync_in_thread(client)
      call_id = sent_invoke_call_id(client)
      message = "Calling focus method of inexistent control: #{client.button.wire_id}"
      client.receive(ACTIONS[:invoke_control_method], { "control_id" => client.button.wire_id, "call_id" => call_id, "result" => nil, "error" => message })

      error = assert_raises(RuntimeError) { waiting.value }
      assert_equal message, error.message
    end

    contract(kind, :python_output, "python_output_is_accepted_and_ignored") do
      client = Harness.new(kind)
      client.register
      sent = client.ws.sent.size

      client.receive(ACTIONS[:python_output], { "message" => "diagnostic" })

      assert_equal sent, client.ws.sent.size
      refute_nil client.page, "the session survives"
    end

    contract(kind, :patch_control, "page_updates_go_out_as_patch_control") do
      client = Harness.new(kind)
      client.register
      client.ws.sent.clear

      client.page.update(client.field, value: "server side")

      action, payload = client.ws.frames.last
      assert_equal ACTIONS[:patch_control], action
      assert_equal client.field.wire_id, payload["id"]
    end

    contract(kind, :session_crashed, "an_app_that_raises_on_register_reports_session_crashed") do
      client = Harness.new(kind) { |_page| raise "boom" }

      assert_raises(RuntimeError) { client.register } if kind == :connection_protocol
      client.register if kind == :server

      crashed = client.ws.frames.find { |action, _| action == ACTIONS[:session_crashed] }
      refute_nil crashed
      assert_equal "boom", crashed[1]["message"]
    end
  end
end
