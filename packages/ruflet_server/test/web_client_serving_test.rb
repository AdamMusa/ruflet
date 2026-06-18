# frozen_string_literal: true

require "tmpdir"
require "stringio"
require "fileutils"

require_relative "test_helper"

class RufletWebClientServingTest < Minitest::Test
  def with_web_client_dir
    Dir.mktmpdir("ruflet_web") do |dir|
      File.write(File.join(dir, "index.html"), "<!DOCTYPE html><html><body>ruflet</body></html>")
      File.write(File.join(dir, "main.dart.js"), "console.log('ruflet')")
      previous = ENV["RUFLET_WEB_CLIENT_DIR"]
      ENV["RUFLET_WEB_CLIENT_DIR"] = dir
      begin
        yield dir
      ensure
        ENV["RUFLET_WEB_CLIENT_DIR"] = previous
      end
    end
  end

  def server
    @server ||= Ruflet::Server.new(host: "127.0.0.1", port: 0) { |_page| nil }
  end

  def request(path)
    io = StringIO.new
    server.send(:handle_http_request, io, path)
    io.string
  end

  def teardown
    @server&.stop
  end

  def test_serves_index_html_with_no_store_cache
    with_web_client_dir do
      out = request("/")
      assert_includes out, "200 OK"
      assert_includes out, "text/html"
      assert_includes out, "<!DOCTYPE html>"
      assert_includes out, "no-store"
    end
  end

  def test_serves_static_js_with_correct_content_type
    with_web_client_dir do
      out = request("/main.dart.js")
      assert_includes out, "200 OK"
      assert_includes out, "text/javascript"
      assert_includes out, "console.log('ruflet')"
    end
  end

  def test_service_worker_is_neutralized
    with_web_client_dir do
      out = request("/flutter_service_worker.js")
      assert_includes out, "200 OK"
      # No-op worker: clears stale caches + claims the page, with no fetch
      # handler (network passthrough). It must NOT self-unregister.
      assert_includes out, "caches.delete"
      assert_includes out, "clients.claim"
      refute_includes out, "registration.unregister"
    end
  end

  def test_extensionless_route_falls_back_to_index_html
    with_web_client_dir do
      out = request("/some/deep/route")
      assert_includes out, "200 OK"
      assert_includes out, "<!DOCTYPE html>"
    end
  end

  def test_path_traversal_is_blocked
    with_web_client_dir do
      out = request("/../server.rb")
      assert_includes out, "404"
    end
  end

  def test_without_web_client_dir_root_is_plain_server_banner
    out = request("/")
    assert_includes out, "ruflet server"
  end

  def test_serves_assets_from_extracted_embedded_app_root
    Dir.mktmpdir("ruflet_embedded") do |dir|
      assets = File.join(dir, "assets")
      FileUtils.mkdir_p(assets)
      File.binwrite(File.join(assets, "icon.png"), "ruflet-logo")
      previous_assets_dir = ENV.delete("RUFLET_ASSETS_DIR")
      previous_app_root = $__ruflet_app_root if defined?($__ruflet_app_root)
      $__ruflet_app_root = dir

      out = request("/assets/icon.png")

      assert_includes out, "200 OK"
      assert_includes out, "image/png"
      assert_includes out, "ruflet-logo"
    ensure
      ENV["RUFLET_ASSETS_DIR"] = previous_assets_dir if previous_assets_dir
      $__ruflet_app_root = previous_app_root
    end
  end

  def test_ws_path_with_query_string_is_treated_as_upgrade
    headers = {
      "upgrade" => "websocket",
      "connection" => "Upgrade",
      "sec-websocket-key" => "dGhlIHNhbXBsZSBub25jZQ=="
    }
    assert server.send(:websocket_upgrade_request?, "/ws?session=1", headers)
  end
end
