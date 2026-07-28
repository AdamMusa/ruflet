# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "stringio"

class RufletWebClientServingTest < Minitest::Test
  class FakeSocket
    attr_reader :written

    def initialize
      @written = +""
    end

    def write(data)
      @written << data.to_s
      data.to_s.bytesize
    end
    alias print write
    alias << write
  end

  def with_web_client_dir(dir)
    previous = ENV["RUFLET_WEB_CLIENT_DIR"]
    ENV["RUFLET_WEB_CLIENT_DIR"] = dir
    yield
  ensure
    ENV["RUFLET_WEB_CLIENT_DIR"] = previous
  end

  def build_web_client(root)
    FileUtils.mkdir_p(File.join(root, "assets"))
    File.write(File.join(root, "index.html"), "<html>ruflet</html>")
    File.write(File.join(root, "flutter_bootstrap.js"), "// bootstrap")
    File.write(File.join(root, "assets", "AssetManifest.json"), "{}")
    root
  end

  def test_serves_the_client_index_at_the_root_so_it_shares_the_backend_origin
    Dir.mktmpdir do |dir|
      build_web_client(dir)
      server = Ruflet::Server.new
      socket = FakeSocket.new

      handled = with_web_client_dir(dir) { server.send(:serve_web_client, socket, "/") }

      assert handled
      assert_includes socket.written, "200 OK"
      assert_includes socket.written, "text/html"
      assert_includes socket.written, "<html>ruflet</html>"
    end
  end

  def test_serves_client_bundle_files_including_its_own_assets
    Dir.mktmpdir do |dir|
      build_web_client(dir)
      server = Ruflet::Server.new

      with_web_client_dir(dir) do
        bootstrap = FakeSocket.new
        assert server.send(:serve_web_client, bootstrap, "/flutter_bootstrap.js")
        assert_includes bootstrap.written, "text/javascript"

        manifest = FakeSocket.new
        assert server.send(:serve_web_client, manifest, "/assets/AssetManifest.json")
        assert_includes manifest.written, "application/json"
      end
    end
  end

  def test_ignores_the_query_string_when_resolving_the_index
    Dir.mktmpdir do |dir|
      build_web_client(dir)
      server = Ruflet::Server.new
      socket = FakeSocket.new

      with_web_client_dir(dir) do
        server.send(:handle_http_request, socket, "/?url=http%3A%2F%2Flocalhost%3A8550")
      end

      assert_includes socket.written, "<html>ruflet</html>"
    end
  end

  def test_never_serves_outside_the_client_bundle
    Dir.mktmpdir do |dir|
      root = File.join(dir, "web")
      build_web_client(root)
      File.write(File.join(dir, "secret.txt"), "secret")
      server = Ruflet::Server.new
      socket = FakeSocket.new

      handled = with_web_client_dir(root) do
        server.send(:serve_web_client, socket, "/../secret.txt")
      end

      refute handled
      refute_includes socket.written, "secret"
    end
  end

  def test_falls_back_to_the_plain_banner_when_no_client_is_configured
    server = Ruflet::Server.new
    socket = FakeSocket.new

    previous = ENV["RUFLET_WEB_CLIENT_DIR"]
    ENV.delete("RUFLET_WEB_CLIENT_DIR")
    begin
      server.send(:handle_http_request, socket, "/")
    ensure
      ENV["RUFLET_WEB_CLIENT_DIR"] = previous
    end

    assert_includes socket.written, "ruflet server"
  end
end
