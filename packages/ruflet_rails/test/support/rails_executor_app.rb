# frozen_string_literal: true

# Boots a minimal Rails app in this process (development reloading,
# FileUpdateChecker, and Active Record on SQLite when the sqlite3 gem is
# available), connects a Ruflet client to Ruflet::Rails.native through a
# Rack-hijacked socket pair, runs one scenario and prints what it observed as
# a single JSON line.
#
# rails_executor_test.rb runs every scenario in its own process: a booted
# Rails app must not share a process with the other test files, some of
# which stub ::Rails.
#
#   ruby -Ilib test/support/rails_executor_app.rb SCENARIO

require "json"
require "tmpdir"
require "fileutils"
require "socket"
require "logger"

RESULT_MARKER = "RUFLET_EXECUTOR_RESULT "

def report(result)
  $stdout.puts(RESULT_MARKER + JSON.generate(result))
  $stdout.flush
  # exit! skips at_exit, so remove the app directory here.
  FileUtils.rm_rf(APP_ROOT) if defined?(APP_ROOT)
  # Socket threads may still be blocked in a read; nothing here needs a
  # graceful shutdown.
  exit!(0)
end

Thread.new do
  sleep 60
  report("error" => "scenario did not finish within 60s")
end

begin
  require "rails"
  require "action_controller/railtie"
rescue LoadError => e
  report("skip" => "Rails is not available: #{e.message}")
end

# Active Record only with its SQLite driver; a bundle without sqlite3 runs the
# scenarios that need no database and skips the others.
ACTIVE_RECORD =
  begin
    require "sqlite3"
    require "active_record/railtie"
    true
  rescue LoadError
    false
  end

APP_ROOT = Dir.mktmpdir("ruflet-rails-executor")
at_exit { FileUtils.rm_rf(APP_ROOT) }
FileUtils.mkdir_p(File.join(APP_ROOT, "app/models"))
FileUtils.mkdir_p(File.join(APP_ROOT, "config"))
File.write(File.join(APP_ROOT, "app/models/widget.rb"), "class Widget\n  VERSION = 1\nend\n")
File.write(File.join(APP_ROOT, "app/models/current.rb"), <<~RUBY)
  class Current < ActiveSupport::CurrentAttributes
    attribute :user
  end
RUBY
File.write(File.join(APP_ROOT, "config/routes.rb"), <<~RUBY)
  Rails.application.routes.draw do
    get "/up", to: ->(_env) { [200, { "content-type" => "text/plain" }, ["v\#{Widget::VERSION}"]] }
  end
RUBY
DB_PATH = File.join(APP_ROOT, "app.sqlite3")
File.write(File.join(APP_ROOT, "config/database.yml"), <<~YAML) if ACTIVE_RECORD
  development:
    adapter: sqlite3
    database: #{DB_PATH}
    pool: 1
    checkout_timeout: 1
YAML

class ExecutorApp < Rails::Application
  config.load_defaults "#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"
  config.root = APP_ROOT
  config.enable_reloading = true # the development default
  config.eager_load = false
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
  config.active_support.deprecation = :silence
  config.hosts.clear
  config.file_watcher = ActiveSupport::FileUpdateChecker
end

ExecutorApp.initialize!

if ACTIVE_RECORD
  ActiveRecord::Base.connection_pool.with_connection do |connection|
    connection.execute("CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)")
  end
  class Note < ActiveRecord::Base; end
end

require "ruflet_rails"

module Wire
  module_function

  def connect(endpoint)
    server_io, client_io = UNIXSocket.pair
    env = {
      "REQUEST_METHOD" => "GET", "PATH_INFO" => "/ws",
      "HTTP_UPGRADE" => "websocket", "HTTP_CONNECTION" => "Upgrade",
      "HTTP_SEC_WEBSOCKET_KEY" => "testkey", "HTTP_SEC_WEBSOCKET_VERSION" => "13",
      "rack.hijack" => -> {}, "rack.hijack_io" => server_io
    }
    status = endpoint.call(env).first
    raise "endpoint did not hijack the socket (status #{status})" unless status == -1

    handshake = +""
    handshake << client_io.readpartial(1024) until handshake.include?("\r\n\r\n")
    send_frame(client_io, Ruflet::WireCodec.pack([
      Ruflet::Protocol::ACTIONS[:register_client],
      { "session_id" => "", "page_name" => "", "page" => { "route" => "/", "width" => 400, "height" => 800 } }
    ]))
    ack = Ruflet::WireCodec.unpack(read_frame(client_io))
    raise "unexpected register reply #{ack.inspect}" unless ack[0] == Ruflet::Protocol::ACTIONS[:register_client]

    patch = Ruflet::WireCodec.unpack(read_frame(client_io))
    [client_io, patch]
  end

  def click(io, wire_id)
    send_frame(io, Ruflet::WireCodec.pack([
      Ruflet::Protocol::ACTIONS[:control_event], { "target" => wire_id, "name" => "click", "data" => "" }
    ]))
  end

  def send_frame(io, payload)
    mask = [1, 2, 3, 4]
    header = [0x82].pack("C")
    length = payload.bytesize
    header << (length < 126 ? [0x80 | length].pack("C") : [0x80 | 126, length].pack("Cn"))
    masked = payload.bytes.each_with_index.map { |byte, index| byte ^ mask[index % 4] }
    io.write(header + mask.pack("C4") + masked.pack("C*"))
  end

  # Returns the next binary frame's payload, or nil once the server closed
  # the socket or nothing arrived within the timeout.
  def read_frame(io, timeout: 5)
    return nil unless io.wait_readable(timeout)

    first = io.read(2)
    return nil unless first && first.bytesize == 2

    opcode = first.getbyte(0) & 0x0f
    length = first.getbyte(1) & 0x7f
    length = io.read(2).unpack1("n") if length == 126
    length = io.read(8).unpack1("Q>") if length == 127
    payload = length.zero? ? "".b : io.read(length)
    return read_frame(io, timeout: timeout) unless opcode == 2

    payload
  end

  def wire_id(node, marker)
    case node
    when Hash
      return node["_i"] if node.values.any? { |value| value.to_s == marker }

      node.each_value { |value| (found = wire_id(value, marker)) && (return found) }
      nil
    when Array
      node.each { |value| (found = wire_id(value, marker)) && (return found) }
      nil
    end
  end
end

def get_up
  status, _headers, body = Rails.application.call(Rack::MockRequest.env_for("http://localhost/up"))
  text = +""
  body.each { |part| text << part }
  body.close if body.respond_to?(:close)
  [status, text]
end

def pop(queue, timeout: 5)
  queue.pop(timeout: timeout)
end

def button(label, &handler)
  Ruflet::UI::ControlFactory.build(:button, content: label).tap { |control| control.on(:click, &handler) }
end

# Wait until the socket thread finished closing the connection.
def wait_until(timeout: 3)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
  until yield
    return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

    sleep 0.02
  end
  true
end

scenario = ARGV.fetch(0)

case scenario
when "reload"
  # A developer edits app code while a native client is connected.
  result = { "baseline" => get_up }
  seen = Queue.new
  endpoint = Ruflet::Rails.native do |page|
    Current.user = "ada"
    page.add(button("Check") { |_event| seen << [Widget::VERSION, Current.user, Current.respond_to?(:role) && Current.role] })
  end
  client, patch = Wire.connect(endpoint)
  check = Wire.wire_id(patch, "Check")

  # FileUpdateChecker ignores mtimes in the future; step past the boot mtime.
  sleep 1.1
  File.write(File.join(APP_ROOT, "app/models/widget.rb"), "class Widget\n  VERSION = 2\nend\n")
  File.write(File.join(APP_ROOT, "app/models/current.rb"), <<~RUBY)
    class Current < ActiveSupport::CurrentAttributes
      attribute :user
      attribute :role, default: "member"
    end
  RUBY

  request = Thread.new { get_up }
  finished = request.join(3)
  result["request_after_edit"] = finished ? request.value : "blocked"

  # The connected client keeps working, now on the reloaded code.
  Wire.click(client, check)
  result["click_after_reload"] = pop(seen)

  client.close
  request.join(5) unless finished
  report(result)

when "query_cache"
  report("skip" => "Active Record or sqlite3 is not available") unless ACTIVE_RECORD

  counts = Queue.new
  endpoint = Ruflet::Rails.native do |page|
    page.add(button("Count") { |_event| counts << Note.count })
    counts << Note.count
  end
  client, patch = Wire.connect(endpoint)
  result = { "before_insert" => pop(counts) }

  # Another process (a job worker, a second Puma worker, the console) writes.
  other = SQLite3::Database.new(DB_PATH)
  other.execute("INSERT INTO notes (body) VALUES ('from another process')")
  other.close

  Wire.click(client, Wire.wire_id(patch, "Count"))
  result["after_insert"] = pop(counts)
  client.close
  report(result)

when "connection_lease"
  report("skip" => "Active Record or sqlite3 is not available") unless ACTIVE_RECORD

  # The pool has a single connection (database.yml). The entrypoint leases
  # it, as `ActiveRecord::Base.connection` does.
  endpoint = Ruflet::Rails.native do |page|
    ActiveRecord::Base.connection.select_value("SELECT 1")
    page.add(button("Idle") { |_event| nil })
  end
  client, = Wire.connect(endpoint)

  # An HTTP request needs a connection while the client stays connected.
  result =
    begin
      { "request_query" => Rails.application.executor.wrap { Note.count } }
    rescue ActiveRecord::ConnectionTimeoutError => e
      { "request_query" => "#{e.class}: #{e.message.lines.first.to_s.strip}" }
    end
  client.close
  report(result)

when "execution_state"
  # What the app sets in the entrypoint or a handler stays set for the rest
  # of the connection, and is reset once, when the client disconnects.
  reset_log = Queue.new
  Current.class_eval do
    attribute :visits, default: 0
    resets { reset_log << :reset }
    def user=(value)
      super
      Time.zone = "Tokyo"
    end
  end
  seen = Queue.new
  endpoint = Ruflet::Rails.native do |page|
    Current.user = "ada"
    Rails.error.set_context(screen: "home")
    ActiveSupport.event_reporter.set_context(shop: 7) if ActiveSupport.respond_to?(:event_reporter)
    page.add(button("Visit") do |_event|
      Current.visits += 1
      seen << {
        "user" => Current.user,
        "visits" => Current.visits,
        "time_zone" => Time.zone&.name,
        "error_context" => ActiveSupport::ExecutionContext.to_h[:screen],
        "event_context" => (ActiveSupport.event_reporter.context[:shop] if ActiveSupport.respond_to?(:event_reporter)),
        "resets" => reset_log.size
      }
    end)
  end
  client, patch = Wire.connect(endpoint)
  visit = Wire.wire_id(patch, "Visit")
  Wire.click(client, visit)
  first = pop(seen)
  Wire.click(client, visit)
  second = pop(seen)
  client.close
  wait_until { reset_log.size.positive? }
  sleep 0.2 # a second reset would show up here
  report(
    "first" => first, "second" => second, "resets_after_disconnect" => reset_log.size,
    "event_reporter" => ActiveSupport.respond_to?(:event_reporter)
  )

when "unhandled_errors"
  # An error raised by the entrypoint or by a handler is handled by the
  # connection protocol as before; the executor does not also report it to
  # Rails.error as an unhandled error.
  reports = Queue.new
  subscriber = Class.new do
    define_method(:report) { |error, **| reports << error.message }
  end.new
  Rails.error.subscribe(subscriber)
  raised = []
  drain = lambda do |io|
    nil while Wire.read_frame(io, timeout: 2)
    io.close
  end

  failing_entrypoint = Ruflet::Rails.native do |_page|
    raised << "entrypoint"
    raise "entrypoint failed"
  end
  client, = Wire.connect(failing_entrypoint)
  drain.call(client)

  failing_handler = Ruflet::Rails.native do |page|
    page.add(button("Boom") do |_event|
      raised << "handler"
      raise "handler failed"
    end)
  end
  client, patch = Wire.connect(failing_handler)
  Wire.click(client, Wire.wire_id(patch, "Boom"))
  drain.call(client)

  sleep 0.2
  report("raised" => raised, "reported" => Array.new(reports.size) { reports.pop })

else
  report("error" => "unknown scenario #{scenario}")
end
