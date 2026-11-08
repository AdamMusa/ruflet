# frozen_string_literal: true

require_relative "test_helper"

# A Form over the real server message path: validators stay in Ruby (never
# packed), the client's change/blur/submit messages drive validation, and a
# hot reload's fresh controls bring their own validators.
class RufletFormWireTest < Minitest::Test
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

  ACTIONS = Ruflet::Protocol::ACTIONS

  def setup
    @submitted = []
    @rule = "Required"
    submitted = @submitted
    test = self
    @server = Ruflet::Server.new(port: 0) do |page|
      # Each run of the app block builds validators bound to that run.
      message = test.rule
      page.add(
        Ruflet.form(autovalidate_mode: "on_unfocus", on_submit: ->(e) { submitted << e.control.values if e.control.validate }) do
          text_field(key: "email", label: "Email", validator: ->(v) { message if v.empty? })
          checkbox(key: "terms", label: "Terms", validator: ->(v) { "Accept" unless v })
        end
      )
    end
    @ws = FakeWs.new
    @server.instance_variable_get(:@connections)[@ws.session_key] = @ws
    receive(ACTIONS[:register_client], { "session_id" => "s1", "page" => { "route" => "/" } })
  end

  def rule = @rule

  def receive(action, payload)
    @server.send(:handle_message, @ws, Ruflet::WireCodec.pack([action, payload]))
  end

  def decoded
    @ws.sent.map { |frame| Ruflet::WireCodec.unpack(frame) }
  end

  def strings_in(value)
    case value
    when String then [value]
    when Hash then value.flat_map { |k, v| strings_in(k.to_s) + strings_in(v) }
    when Array then value.flat_map { |v| strings_in(v) }
    else []
    end
  end

  def page
    @server.instance_variable_get(:@sessions)[@ws.session_key]
  end

  def field(key)
    page.controls.first.fields.find { |f| f.props["key"] == key }
  end

  def error_patches
    decoded.filter_map do |action, payload|
      next unless action == ACTIONS[:patch_control] && payload["id"] != 1

      [payload["id"], payload["patch"].drop(1).to_h { |(_op, _i, key, value)| [key, value] }]
    end
  end

  def test_the_register_response_carries_the_form_and_its_flags_but_no_validator
    _action, response = decoded.first
    form = response["page_patch"]["views"].first["controls"].first
    email, terms = form["controls"]

    assert_equal "Form", form["_c"]
    assert_equal true, form["on_submit"]
    assert_equal true, email["on_blur"], "on_unfocus asks the client for blur events"
    assert_equal true, email["on_submit"], "on_submit asks text fields for submit events"
    assert_equal true, terms["on_blur"]
    refute terms.key?("on_submit")
    strings = strings_in(decoded)
    assert_empty strings.grep(/#<(Proc|Method)/)
    %w[validator on_saved autovalidate_mode].each { |name| refute_includes strings, name }
  end

  def test_client_messages_drive_blur_validation_and_submit
    email = field("email")
    @ws.sent.clear

    receive(ACTIONS[:update_control], { "id" => email.wire_id, "props" => { "value" => "" } })
    receive(ACTIONS[:control_event], { "target" => email.wire_id, "name" => "blur", "data" => nil })
    assert_equal [[email.wire_id, { "error" => "Required" }]], error_patches

    @ws.sent.clear
    receive(ACTIONS[:update_control], { "id" => email.wire_id, "props" => { "value" => "ada@example.com" } })
    receive(ACTIONS[:control_event], { "target" => email.wire_id, "name" => "submit", "data" => "ada@example.com" })
    assert_empty @submitted, "terms is not accepted yet"
    assert_equal({ "error" => true }, error_patches.to_h[field("terms").wire_id])
    assert_equal({ "error" => nil }, error_patches.to_h[email.wire_id])

    terms = field("terms")
    receive(ACTIONS[:update_control], { "id" => terms.wire_id, "props" => { "value" => true } })
    receive(ACTIONS[:control_event], { "target" => email.wire_id, "name" => "submit", "data" => "ada@example.com" })
    assert_equal [{ "email" => "ada@example.com", "terms" => true }], @submitted
    assert_empty strings_in(decoded).grep(/#<(Proc|Method)/)
  end

  def test_hot_reload_brings_the_reloaded_blocks_validators
    old_email = field("email")
    @rule = "Email is required"

    @server.reload_app!

    email = field("email")
    refute_same old_email, email
    @ws.sent.clear
    receive(ACTIONS[:control_event], { "target" => email.wire_id, "name" => "blur", "data" => nil })
    assert_equal [[email.wire_id, { "error" => "Email is required" }]], error_patches
    assert_empty strings_in(decoded).grep(/#<(Proc|Method)/)
  end
end
