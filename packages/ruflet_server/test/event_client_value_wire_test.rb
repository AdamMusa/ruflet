# frozen_string_literal: true

require_relative "test_helper"

# A control's value reaches its handler as the String the client sent, on
# both receivers: Ruflet::Server#handle_message (ruflet run and the embedded
# runtime) and a Ruflet::ConnectionProtocol host (ruflet_rails). The frames
# are the ones textfield.dart, material_dropdown.dart and radio_group.dart
# send: update_control with the value, then the event with the value as data.
class EventClientValueWireTest < Minitest::Test
  ACTIONS = Ruflet::Protocol::ACTIONS

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

    def close; end

    def send_binary(bytes)
      @sent << bytes
    end
  end

  class ProtocolHost
    include Ruflet::ConnectionProtocol

    def initialize(&app_block)
      @app_block = app_block
      @sessions = {}
      @sessions_mutex = Mutex.new
    end
  end

  RECEIVERS = {
    server: ->(app) { Ruflet::Server.new(port: 0, &app) },
    connection_protocol: ->(app) { ProtocolHost.new(&app) }
  }.freeze

  def connect(kind, &app)
    @receiver = RECEIVERS.fetch(kind).call(app)
    @ws = FakeWs.new
    receive(ACTIONS[:register_client], { "session_id" => "", "page" => { "route" => "/" } })
  end

  def receive(action, payload)
    @receiver.send(:handle_message, @ws, Ruflet::WireCodec.pack([action, payload]))
  end

  def client_sends(control, name, value, prop: "value")
    receive(ACTIONS[:update_control], { "id" => control.wire_id, "props" => { prop => value } })
    receive(ACTIONS[:control_event], { "target" => control.wire_id, "name" => name, "data" => value })
  end

  RECEIVERS.each_key do |kind|
    define_method("test_#{kind}_text_field_handlers_get_the_typed_text") do
      seen = []
      field = nil
      connect(kind) do |page|
        field = Ruflet.text_field(label: "Price", on_change: ->(e) { seen << [e.data, e.value, e.control.props["value"]] })
        page.add(field)
      end

      typed = ["2.50", "1e3", "null", " 42", "true", "[1]", "007"]
      typed.each { |text| client_sends(field, "change", text) }

      assert_equal typed.map { |text| [text, text, text] }, seen
    end

    define_method("test_#{kind}_a_form_validator_gets_the_typed_text") do
      field = nil
      form_seen = []
      connect(kind) do |page|
        page.add(
          Ruflet.form(autovalidate_mode: "always", on_change: ->(e) { form_seen << e.data }) do
            field = text_field(key: "zip", label: "ZIP", on_change: ->(_e) {},
                               validator: ->(v) { "Required" if v.strip.empty? })
          end
        )
      end

      client_sends(field, "change", "2.50")

      assert_equal "2.50", field.props["value"]
      assert_equal ["2.50"], form_seen
      assert_nil field.props["error"]
    end

    define_method("test_#{kind}_picked_keys_and_values_keep_the_declared_type") do
      seen = []
      strings = ints = group = nil
      connect(kind) do |page|
        strings = Ruflet.dropdown(value: "1", options: [Ruflet.dropdown_option(key: "1", text: "One"), Ruflet.dropdown_option(key: "2", text: "Two")],
                                  on_select: ->(e) { seen << [:strings, e.data] })
        ints = Ruflet.dropdown(value: 1, options: [Ruflet.dropdown_option(key: 1, text: "One"), Ruflet.dropdown_option(key: 2, text: "Two")],
                               on_select: ->(e) { seen << [:ints, e.data] })
        group = Ruflet.radio_group(value: "10", content: Ruflet.column(controls: [Ruflet.radio(value: "10"), Ruflet.radio(value: "20")]),
                                   on_change: ->(e) { seen << [:radio, e.data, e.control.props["value"]] })
        page.add(Ruflet.column(controls: [strings, ints, group]))
      end

      client_sends(strings, "select", "2")
      client_sends(ints, "select", "2")
      client_sends(group, "change", "20")

      assert_equal [[:strings, "2"], [:ints, 2], [:radio, "20", "20"]], seen
    end

    # Radios inside a Form still join the RadioGroup above it.
    define_method("test_#{kind}_integer_radios_inside_a_form_keep_their_type") do
      seen = []
      group = nil
      connect(kind) do |page|
        group = Ruflet.radio_group(content: Ruflet.form(controls: [Ruflet.radio(value: 1, label: "One"), Ruflet.radio(value: 2, label: "Two")]),
                                   on_change: ->(e) { seen << [e.data, e.control.props["value"]] })
        page.add(group)
      end

      client_sends(group, "change", "2")

      assert_equal [[2, 2]], seen
    end
  end
end
