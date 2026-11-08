# frozen_string_literal: true

# Runs one fixture app and records what a client receives in reply to
# register_client: the initial page patch plus anything flushed with it.
# Spawned by lib/harness.rb as
#
#   ruby -I<installed gem libs>... page_child.rb <spec.json>
#
# The real Ruflet::Server handles the registration through a fake WebSocket
# (no socket is opened); Ruflet.run is intercepted with the public
# Ruflet.with_run_interceptor hook.

Encoding.default_external = Encoding::UTF_8

require "json"
require "securerandom"
require "socket"
require "stringio"

module CompatPage
  SPEC = JSON.parse(File.read(ARGV.fetch(0)))
  MESSAGES = []
  WIRE_ID_KEYS = %w[_i id control_id target].freeze
  REGISTER_PAYLOAD = {
    "session_id" => "compat-session",
    "page_name" => "",
    "page" => {
      "route" => "/",
      "width" => 430,
      "height" => 932,
      "platform" => "ios",
      "platform_brightness" => "light",
      "window" => {},
      "media" => {}
    }
  }.freeze

  class FakeWS
    def session_key = 1
    def closed? = false
    def close = nil

    def send_binary(bytes)
      MESSAGES << Ruflet::WireCodec.unpack(bytes)
    end

    def send_text(payload) = send_binary(payload)
  end

  class << self
    def serve(entrypoint)
      raise "the app called Ruflet.run more than once" if @served

      @served = true
      server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |page| entrypoint.call(page) }
      server.send(:on_register_client, FakeWS.new, REGISTER_PAYLOAD)
      :served
    end

    def served? = !!@served

    # Wire ids and generated ids are renumbered in order of first appearance:
    # their absolute values are allocation details, their structure is not.
    def normalize(value, ids = {}, tokens = Hash.new { |hash, key| hash[key] = {} })
      case value
      when Hash
        value.each_with_object({}) do |(key, item), out|
          out[key.to_s] = if WIRE_ID_KEYS.include?(key.to_s) && item.is_a?(Integer)
                            ids[item] ||= "##{ids.length + 1}"
                          else
                            normalize(item, ids, tokens)
                          end
        end
      when Array
        value.map { |item| normalize(item, ids, tokens) }
      when String
        string = value.dup.force_encoding(Encoding::UTF_8).scrub("?")
        string.gsub(/\b(ctrl|call)_[0-9a-f]{8}\b/) do
          table = tokens[Regexp.last_match(1)]
          table[Regexp.last_match(0)] ||= "#{Regexp.last_match(1)}##{table.length + 1}"
        end
      when Float
        value.finite? ? value : value.to_s
      else
        value
      end
    end

    def action_name(action)
      Ruflet::Protocol::ACTIONS.key(action)&.to_s || action
    end
  end
end

# Determinism: generated ids are counters, and nothing reaches the network.
srand(20_260_101)
module SecureRandom
  @compat_counter = 0
  class << self
    def hex(n = 16)
      @compat_counter += 1
      format("%0#{n * 2}x", @compat_counter)[-(n * 2)..]
    end

    def uuid
      @compat_counter += 1
      format("00000000-0000-4000-8000-%012x", @compat_counter)
    end
  end
end
[TCPSocket.singleton_class, Socket.singleton_class].each do |klass|
  klass.prepend(Module.new do
    %i[new open tcp].each do |name|
      define_method(name) { |*args, **_kwargs| raise SocketError, "compat harness: network access is disabled (#{args.first})" }
    end
  end)
end

# Everything runs inside a method: the app is evaluated in TOPLEVEL_BINDING
# like `ruby main.rb`, and must not see (or clobber) locals of this script.
def compat_page_run!
  real_stdout = $stdout
  $stdout = StringIO.new
  $stderr = StringIO.new
  project = CompatPage::SPEC.fetch("project")
  entrypoint = File.join(project, CompatPage::SPEC.fetch("entrypoint"))
  outcome = { "fixture" => CompatPage::SPEC.fetch("fixture"), "entrypoint" => CompatPage::SPEC.fetch("entrypoint") }

  begin
    Dir.chdir(project) do
      if CompatPage::SPEC["rails_stub"]
        require_relative "rails_stub"
        CompatRails.boot(project)
      elsif CompatPage::SPEC["rails"]
        require "ruflet_rails"
      end
      require "ruflet"
      require "ruflet_server"
      TOPLEVEL_BINDING.eval(CompatPage::SPEC["prelude"], "(prelude)", 1) if CompatPage::SPEC["prelude"]
      interceptor = ->(entrypoint:, host:, port:) { CompatPage.serve(entrypoint) }
      Ruflet.with_run_interceptor(interceptor) do
        TOPLEVEL_BINDING.eval(File.read(entrypoint, encoding: Encoding::UTF_8), entrypoint, 1)
      end
    end
    outcome["status"] = CompatPage.served? ? "ok" : "did_not_call_ruflet_run"
  rescue Exception => e # rubocop:disable Lint/RescueException
    outcome["status"] = "error"
    outcome["error"] = { "class" => e.class.name, "message" => e.message.to_s }
  end

  outcome["messages"] = CompatPage.normalize(
    CompatPage::MESSAGES.map { |action, payload| { "action" => CompatPage.action_name(action), "payload" => payload } }
  )
  outcome["stdout"] = $stdout.string
  outcome["stderr"] = $stderr.string
  File.write(CompatPage::SPEC.fetch("result_path"), JSON.generate(outcome))
  real_stdout.flush
end

compat_page_run!
exit!(0)
