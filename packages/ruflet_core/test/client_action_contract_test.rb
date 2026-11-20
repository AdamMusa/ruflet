# frozen_string_literal: true

require_relative "test_helper"

# A client action is a service call the client makes on its own, inside the
# tap. The renderer runs it through the same service method a Ruby call
# reaches, so every action must name a service and method Ruby can call, and
# send each option under the arg the Ruby method sends it under.
class ClientActionContractTest < Minitest::Test
  OPTION_SAMPLES = {
    "url" => ["https://ruflet.dev", "https://ruflet.dev"],
    "string" => ["Ruflet", "Ruflet"],
    "text" => ["Copied", "Copied"],
    "boolean" => [true, true],
    "launch_mode" => [:external_application, "external_application"],
    "file_type" => [:image, "image"],
    "extensions" => [%i[png jpg], %w[png jpg]],
    "files" => [["notes.txt"], [{ "path" => "notes.txt" }]]
  }.freeze

  # The Ruby service call each action stands for, with every option set.
  RUBY_CALLS = {
    "launch_url" => ->(s) { s.launch_url("https://ruflet.dev", mode: :external_application, web_only_window_name: "_blank") },
    "copy_to_clipboard" => ->(s) { s.set("Copied") },
    "pick_files" => lambda { |s|
      s.pick_files(dialog_title: "Pick", initial_directory: "/", file_type: :image, allowed_extensions: %w[png],
                   allow_multiple: true, with_data: true)
    },
    "share_text" => ->(s) { s.share_text("Hi", title: "T", subject: "S") },
    "share_uri" => ->(s) { s.share_uri("https://ruflet.dev") },
    "share_files" => ->(s) { s.share_files([{ path: "notes.txt" }], text: "Hi", title: "T", subject: "S") }
  }.freeze

  def test_every_action_has_a_ruby_service_call
    assert_equal Ruflet::ClientAction::ACTIONS.keys.sort, RUBY_CALLS.keys.sort
  end

  Ruflet::ClientAction::ACTIONS.each do |type, spec|
    define_method("test_#{type}_sends_each_option_under_its_wire_arg") do
      spec[:options].each do |option, (arg, kind)|
        input, expected = OPTION_SAMPLES.fetch(kind)
        required = spec[:required].reject { |name| name == option }.to_h do |name|
          [name.to_sym, OPTION_SAMPLES.fetch(spec[:options][name][1]).first]
        end
        action = Ruflet::ClientAction.new(type, **required, option.to_sym => input)

        assert_equal spec[:service], action.to_h["service"]
        assert_equal spec[:method], action.to_h["method"]
        assert_equal expected, action.to_h["args"][arg], "#{type} #{option} is sent as #{arg}"
      end
    end

    define_method("test_#{type}_matches_the_ruby_service_method") do
      sent = []
      page = Ruflet::Page.new(session_id: "s", client_details: { "route" => "/" },
                              sender: ->(action, payload) { sent << [action, payload] })
      service = page.service(service_type(spec[:service]))
      sent.clear

      RUBY_CALLS.fetch(type).call(service)

      payload = sent.find { |action, _| action == Ruflet::Protocol::ACTIONS[:invoke_control_method] }&.last
      refute_nil payload
      assert_equal spec[:service], service.to_patch["_c"]
      assert_equal spec[:method], payload["name"]
      action_args = spec[:options].values.map(&:first)
      assert_empty action_args - payload["args"].keys, "#{type} sends args the Ruby method never sends"
    end
  end

  def test_aliases_resolve_to_actions_and_their_options
    Ruflet::ClientAction::TYPE_ALIASES.each do |alias_name, type|
      assert Ruflet::ClientAction::ACTIONS.key?(type)
      required = Ruflet::ClientAction::ACTIONS[type][:required].to_h { |name| [name.to_sym, "https://ruflet.dev"] }
      assert_equal type, Ruflet::ClientAction.new(alias_name, **required).type
    end

    Ruflet::ClientAction::OPTION_ALIASES.each do |type, aliases|
      aliases.each_value { |option| assert Ruflet::ClientAction::ACTIONS[type][:options].key?(option) }
    end
  end

  private

  def service_type(wire)
    Ruflet::UI::Services::RufletServices::CLASS_MAP.find { |_, klass| klass::WIRE == wire }.first
  end
end
