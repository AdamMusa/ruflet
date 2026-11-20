# frozen_string_literal: true

require_relative "test_helper"

# What a Flutter client does when the user changes a control: it sends
# update_control with the new property value and then the control event. The
# documented handlers read that value back as `event.control.value`, and later
# code reads it as `field.value`.
class RufletControlValueReadersWireTest < Minitest::Test
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

    def send_binary(bytes)
      @sent << bytes
    end
  end

  def register(server)
    ws = FakeWs.new
    server.instance_variable_get(:@connections)[ws.session_key] = ws
    server.send(:on_register_client, ws, { "session_id" => "s1", "page" => { "route" => "/" } })
    ws
  end

  def test_handler_reads_the_value_the_client_just_set
    observed = []
    toggle = nil
    server = Ruflet::Server.new(port: 0) do |page|
      toggle = Ruflet.switch(
        label: "Email notifications",
        value: true,
        on_change: ->(event) { observed << event.control.value }
      )
      page.add(toggle)
    end
    ws = register(server)

    server.send(:on_update_control, ws, { "id" => toggle.wire_id, "props" => { "value" => false } })
    server.send(:on_control_event, ws, { "target" => toggle.wire_id, "name" => "change", "data" => false })

    assert_equal [false], observed
    assert_equal false, toggle.value
  end

  def test_later_code_reads_the_current_selection
    field = nil
    save = nil
    read_back = []
    server = Ruflet::Server.new(port: 0) do |page|
      field = Ruflet.dropdown(
        label: "Size",
        options: [Ruflet.dropdown_option(key: "s", text: "Small"), Ruflet.dropdown_option(key: "l", text: "Large")]
      )
      save = Ruflet.button(content: Ruflet.text("Save"), on_click: ->(_e) { read_back << field.value })
      page.add(Ruflet.column(controls: [field, save]))
    end
    ws = register(server)

    assert_nil field.value
    server.send(:on_update_control, ws, { "id" => field.wire_id, "props" => { "value" => "s" } })
    server.send(:on_control_event, ws, { "target" => field.wire_id, "name" => "select", "data" => "s" })
    server.send(:on_control_event, ws, { "target" => save.wire_id, "name" => "click", "data" => nil })

    assert_equal ["s"], read_back
  end
end
