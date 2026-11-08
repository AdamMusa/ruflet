# frozen_string_literal: true

# Runs one fixture app and records what a client receives in reply to
# register_client: the initial page patch plus anything flushed with it.
# Spawned by lib/harness.rb as
#
#   ruby -I<installed gem libs>... page_child.rb <spec.json>
#
# Two servers, as an app is served today:
#
# * default: the real Ruflet::Server (`ruflet run`) handles the registration
#   through a fake WebSocket (no socket is opened); Ruflet.run is intercepted
#   with the public Ruflet.with_run_interceptor hook. The reply carries the
#   whole page as `register_page_patch`.
# * spec "mode" == "rails_endpoint": the Rack endpoint a Rails app mounts in
#   config/routes.rb, `Ruflet::Rails.native(<app file>)`, is called with a
#   WebSocket upgrade env and a hijacked socket pair, and a client speaks real
#   WebSocket frames to it. That runs Ruflet::Rails::Protocol::LocalServer
#   (Ruflet::ConnectionProtocol): `register_client` without a page patch,
#   then the page as `page.update` op patches.
#
# An error in this driver (not in the app) is a harness fault: it is written
# to the result file and lib/harness.rb fails the golden with it.

Encoding.default_external = Encoding::UTF_8

require "io/wait"
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

  # For the rails_endpoint mode.
  WS_KEY = "dGhlIHNhbXBsZSBub25jZQ==" # RFC 6455's sample nonce
  WS_MASK = [0x37, 0xfa, 0x21, 0x3d].pack("C4")
  WS_TIMEOUT = 30

  class HarnessFault < StandardError; end

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
      # Server#on_register_client is private: it is what the WebSocket loop
      # calls for a register_client message, and there is no public entry
      # point that takes a socket. If it is renamed, every page golden fails
      # with this message (never silently); point this line at the new name.
      unless server.respond_to?(:on_register_client, true)
        raise NotImplementedError, "compat page child: Ruflet::Server#on_register_client is gone; update lib/page_child.rb"
      end

      server.send(:on_register_client, FakeWS.new, REGISTER_PAYLOAD)
      :served
    end

    def served? = !!@served

    # --- rails_endpoint ------------------------------------------------------

    # What Puma does for a GET /ws upgrade: call the mounted Rack app with
    # rack.hijack, then hand the socket over. Returns what the client saw.
    def serve_rails_endpoint(app_file)
      endpoint = Ruflet::Rails.native(app_file) # config/routes.rb's `to:`
      client, server_io = UNIXSocket.pair
      env = {
        "REQUEST_METHOD" => "GET", "PATH_INFO" => "/ws", "HTTP_UPGRADE" => "websocket",
        "HTTP_CONNECTION" => "Upgrade", "HTTP_SEC_WEBSOCKET_KEY" => WS_KEY, "HTTP_SEC_WEBSOCKET_VERSION" => "13"
      }
      env["rack.hijack"] = -> { env["rack.hijack_io"] = server_io }
      before = Thread.list
      rack_response = endpoint.call(env)
      handlers = Thread.list - before
      handshake = read_handshake(client)
      register = Ruflet::WireCodec.pack([Ruflet::Protocol::ACTIONS[:register_client], REGISTER_PAYLOAD])
      client.write(client_frame(0x2, register))
      # The client sends nothing more; the server answers, reads EOF and
      # closes the connection, which ends the frames below.
      client.close_write
      frames = read_frames(client)
      handlers.each do |thread|
        raise HarnessFault, "the endpoint's socket thread did not finish" unless thread.join(WS_TIMEOUT)
      end
      frames.each { |opcode, payload| MESSAGES << Ruflet::WireCodec.unpack(payload) if [0x1, 0x2].include?(opcode) }
      @served = true
      {
        "rack_response" => rack_response.map { |part| part.is_a?(Hash) ? part.sort.to_h : part },
        "handshake" => handshake,
        # One WebSocket frame per message; 2 is binary.
        "frame_opcodes" => frames.map(&:first)
      }
    ensure
      client&.close unless client&.closed?
    end

    def read_handshake(io)
      head = +"".b
      until head.end_with?("\r\n\r\n")
        chunk = wait_read(io, 1)
        raise HarnessFault, "the endpoint closed the socket during the handshake: #{head.inspect}" if chunk.nil?

        head << chunk
      end
      head.force_encoding(Encoding::UTF_8).split("\r\n")
    end

    # Client frames are masked (RFC 6455 5.3), as a Flutter client sends them.
    def client_frame(opcode, payload)
      bytes = payload.b
      length = if bytes.bytesize <= 125 then [0x80 | bytes.bytesize].pack("C")
               elsif bytes.bytesize <= 0xffff then [0x80 | 126, bytes.bytesize].pack("Cn")
               else [0x80 | 127, bytes.bytesize].pack("CQ>")
               end
      masked = bytes.bytes.each_with_index.map { |byte, index| byte ^ WS_MASK.getbyte(index % 4) }.pack("C*")
      [0x80 | opcode].pack("C") + length + WS_MASK + masked
    end

    def read_frames(io)
      frames = []
      loop do
        header = wait_read(io, 2)
        break if header.nil?

        raise HarnessFault, "the server sent a masked frame" if header.getbyte(1) & 0x80 != 0

        opcode = header.getbyte(0) & 0x0f
        length = header.getbyte(1) & 0x7f
        length = frame_part(io, 2).unpack1("n") if length == 126
        length = frame_part(io, 8).unpack1("Q>") if length == 127
        payload = length.zero? ? +"".b : frame_part(io, length)

        frames << [opcode, payload]
      end
      frames
    end

    def frame_part(io, length)
      wait_read(io, length) || raise(HarnessFault, "the connection closed mid-frame")
    end

    # Exactly `length` bytes, or nil at EOF before any byte.
    def wait_read(io, length)
      data = +"".b
      while data.bytesize < length
        raise HarnessFault, "no data from the endpoint within #{WS_TIMEOUT}s" unless io.wait_readable(WS_TIMEOUT)

        chunk = io.read_nonblock(length - data.bytesize, exception: false)
        next if chunk == :wait_readable
        return nil if chunk.nil? && data.empty?
        raise HarnessFault, "the connection closed mid-read" if chunk.nil?

        data << chunk
      end
      data
    end

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
# like `ruby main.rb` (or loaded per session, as the Rails endpoint does), and
# must not see (or clobber) locals of this script.
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
      if CompatPage::SPEC["mode"] == "rails_endpoint"
        outcome["mode"] = "rails_endpoint"
        outcome["mounted_as"] = "Ruflet::Rails.native(#{CompatPage::SPEC.fetch('entrypoint').inspect})"
        outcome.merge!(CompatPage.serve_rails_endpoint(entrypoint))
      else
        interceptor = ->(entrypoint:, host:, port:) { CompatPage.serve(entrypoint) }
        Ruflet.with_run_interceptor(interceptor) do
          TOPLEVEL_BINDING.eval(File.read(entrypoint, encoding: Encoding::UTF_8), entrypoint, 1)
        end
      end
    end
    outcome["status"] = CompatPage.served? ? "ok" : "did_not_call_ruflet_run"
  rescue CompatPage::HarnessFault => e
    File.write(CompatPage::SPEC.fetch("result_path"), JSON.generate("harness_fault" => "#{e.class}: #{e.message}",
                                                                    "backtrace" => Array(e.backtrace).first(12)))
    exit!(70)
  rescue Exception => e # rubocop:disable Lint/RescueException
    outcome["status"] = "error"
    outcome["error"] = { "class" => e.class.name, "message" => e.message.to_s }
  end

  outcome["messages"] = CompatPage.normalize(
    CompatPage::MESSAGES.map { |action, payload| { "action" => CompatPage.action_name(action), "payload" => payload } }
  )
  outcome["stdout"] = $stdout.string
  outcome["stderr"] = $stderr.string
  begin
    File.write(CompatPage::SPEC.fetch("result_path"), JSON.generate(outcome))
  rescue Exception => e # rubocop:disable Lint/RescueException
    STDERR.write("page child could not write its result: #{e.class}: #{e.message}\n")
    exit!(71)
  end
  real_stdout.flush
end

compat_page_run!
exit!(0)
