# frozen_string_literal: true

require_relative "test_helper"
require "socket"
require "tmpdir"

class RufletWebAppTest < Minitest::Test
  def with_build_dir
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "index.html"), <<~HTML)
        <!DOCTYPE html>
        <html>
        <head>
          <base href="/">
          <title>demo</title>
        </head>
        <body></body>
        </html>
      HTML
      File.write(File.join(dir, "flutter.js"), "// flutter loader")
      FileUtils.mkdir_p(File.join(dir, "assets"))
      File.write(File.join(dir, "assets", "data.json"), "{}")
      yield dir
    end
  end

  def app_for(dir)
    Ruflet::Rails.web_app(build_dir: dir) { |page| page.title = "Mounted" }
  end

  def test_index_base_href_follows_the_mount_point
    with_build_dir do |dir|
      app = app_for(dir)
      status, headers, body = app.call("PATH_INFO" => "/", "SCRIPT_NAME" => "/myfrontend", "REQUEST_METHOD" => "GET")

      assert_equal 200, status
      assert_includes headers["content-type"], "text/html"
      html = body.join
      assert_includes html, '<base href="/myfrontend/">'
      refute_includes html, '<base href="/">'
    end
  end

  def test_index_pins_the_client_to_the_mount_via_url_param
    with_build_dir do |dir|
      app = app_for(dir)
      _status, _headers, body = app.call("PATH_INFO" => "/", "SCRIPT_NAME" => "/myfrontend", "REQUEST_METHOD" => "GET")

      html = body.join
      assert_includes html, "window.flet.webSocketEndpoint",
                      "index must steer the web client's WebSocket to the mount point"
      assert html.index("<base href=") < html.index("window.flet.webSocketEndpoint"),
             "bootstrap script must come after <base href> so baseURI is final"
    end
  end

  def test_index_served_at_mount_root_without_trailing_slash
    with_build_dir do |dir|
      app = app_for(dir)
      status, _headers, body = app.call("PATH_INFO" => "", "SCRIPT_NAME" => "/counter", "REQUEST_METHOD" => "GET")

      assert_equal 200, status
      assert_includes body.join, '<base href="/counter/">'
    end
  end

  def test_index_injects_base_when_missing
    with_build_dir do |dir|
      File.write(File.join(dir, "index.html"), "<html><head><title>x</title></head><body></body></html>")
      app = app_for(dir)
      _status, _headers, body = app.call("PATH_INFO" => "/", "SCRIPT_NAME" => "/m", "REQUEST_METHOD" => "GET")

      assert_includes body.join, '<base href="/m/">'
    end
  end

  def test_serves_static_files_with_content_type
    with_build_dir do |dir|
      app = app_for(dir)
      status, headers, body = app.call("PATH_INFO" => "/flutter.js", "SCRIPT_NAME" => "/myfrontend", "REQUEST_METHOD" => "GET")

      assert_equal 200, status
      assert_equal "application/javascript", headers["content-type"]
      assert_equal "// flutter loader", body.join

      status, headers, = app.call("PATH_INFO" => "/assets/data.json", "SCRIPT_NAME" => "/myfrontend", "REQUEST_METHOD" => "GET")
      assert_equal 200, status
      assert_equal "application/json", headers["content-type"]
    end
  end

  def test_blocks_path_traversal
    with_build_dir do |dir|
      app = app_for(dir)
      status, = app.call("PATH_INFO" => "/../../etc/passwd", "SCRIPT_NAME" => "/m", "REQUEST_METHOD" => "GET")
      assert_equal 404, status
    end
  end

  def test_missing_build_reports_actionable_error
    app = Ruflet::Rails.web_app(build_dir: "/nonexistent/build") { |page| page.title = "x" }
    status, _headers, body = app.call("PATH_INFO" => "/", "SCRIPT_NAME" => "/m", "REQUEST_METHOD" => "GET")

    assert_equal 404, status
    assert_includes body.join, "rake ruflet:build[web]"
  end

  def test_websocket_upgrade_runs_the_ruflet_protocol_under_the_mount
    with_build_dir do |dir|
      server_io, client_io = UNIXSocket.pair
      app = app_for(dir)

      env = {
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/",
        "SCRIPT_NAME" => "/myfrontend",
        "HTTP_UPGRADE" => "websocket",
        "HTTP_CONNECTION" => "Upgrade",
        "HTTP_SEC_WEBSOCKET_KEY" => "testkey",
        "rack.hijack" => lambda { },
        "rack.hijack_io" => server_io
      }
      status, = app.call(env)
      assert_equal(-1, status, "upgrade should hijack the socket")

      response = +""
      response << client_io.readpartial(1024) until response.include?("\r\n\r\n")
      assert_includes response, "101 Switching Protocols"

      send_client_frame(client_io, Ruflet::WireCodec.pack([
        Ruflet::Protocol::ACTIONS[:register_client],
        { "session_id" => "", "page_name" => "",
          "page" => { "route" => "/", "width" => 100, "height" => 100,
                      "platform" => "web", "platform_brightness" => "light", "media" => {} } }
      ]))

      ack = Ruflet::WireCodec.unpack(read_server_frame(client_io))
      assert_equal Ruflet::Protocol::ACTIONS[:register_client], ack[0]

      patch = Ruflet::WireCodec.unpack(read_server_frame(client_io))
      assert_equal Ruflet::Protocol::ACTIONS[:patch_control], patch[0]
      assert_includes patch[1].inspect, "Mounted"
    ensure
      client_io&.close rescue nil
      server_io&.close rescue nil
    end
  end

  def test_web_app_accepts_view_option_resolved_lazily
    with_build_dir do |dir|
      app = Ruflet::Rails.web_app(view: "LazyDefinedCounterView", build_dir: dir)

      # The class does not exist yet — resolution must happen per session.
      Object.const_set(:LazyDefinedCounterView, Class.new do
        def self.render(page)
          page.title = "Lazy View"
        end
      end)

      server_io, client_io = UNIXSocket.pair
      status, = app.call(ws_env(server_io))
      assert_equal(-1, status)
      response = +""
      response << client_io.readpartial(1024) until response.include?("\r\n\r\n")

      send_client_frame(client_io, Ruflet::WireCodec.pack([
        Ruflet::Protocol::ACTIONS[:register_client],
        { "session_id" => "", "page_name" => "",
          "page" => { "route" => "/", "width" => 10, "height" => 10,
                      "platform" => "web", "platform_brightness" => "light", "media" => {} } }
      ]))
      read_server_frame(client_io) # ack
      patch = Ruflet::WireCodec.unpack(read_server_frame(client_io))
      assert_includes patch[1].inspect, "Lazy View"
    ensure
      Object.send(:remove_const, :LazyDefinedCounterView) if Object.const_defined?(:LazyDefinedCounterView)
      client_io&.close rescue nil
      server_io&.close rescue nil
    end
  end

  def test_web_app_rejects_multiple_entrypoint_sources
    assert_raises(ArgumentError) do
      Ruflet::Rails.web_app(view: "A", app_file: "b.rb")
    end
    assert_raises(ArgumentError) do
      Ruflet::Rails.web_app(view: "A") { |page| page }
    end
  end

  private

  def ws_env(io)
    {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/",
      "SCRIPT_NAME" => "/m",
      "HTTP_UPGRADE" => "websocket",
      "HTTP_CONNECTION" => "Upgrade",
      "HTTP_SEC_WEBSOCKET_KEY" => "testkey",
      "rack.hijack" => lambda { },
      "rack.hijack_io" => io
    }
  end

  def send_client_frame(io, payload)
    mask = [1, 2, 3, 4]
    header = [0x82, 0x80 | payload.bytesize].pack("CC")
    masked = payload.bytes.each_with_index.map { |byte, index| byte ^ mask[index % 4] }
    io.write(header + mask.pack("C4") + masked.pack("C*"))
  end

  def read_server_frame(io)
    first = io.read(2)
    raise "closed" unless first

    length = first.getbyte(1) & 0x7f
    length = io.read(2).unpack1("n") if length == 126
    length = io.read(8).unpack1("Q>") if length == 127
    io.read(length)
  end
end
