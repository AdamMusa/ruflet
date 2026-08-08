# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class DesktopLauncherTest < Minitest::Test
  def setup
    Ruflet::Rails::DesktopLauncher.reset!
  end

  def teardown
    Ruflet::Rails::DesktopLauncher.reset!
  end

  def test_backend_url_uses_ruflet_yaml
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "ruflet.yaml"), <<~YAML)
        app:
          backend_url: http://localhost:4000
      YAML

      assert_equal "http://localhost:4000", Ruflet::Rails::DesktopLauncher.backend_url(root: dir, argv: ["server"], env: {})
    end
  end

  def test_backend_url_replaces_yaml_port_with_rails_server_port_flag
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "ruflet.yaml"), <<~YAML)
        app:
          backend_url: http://localhost:3000
      YAML

      assert_equal "http://localhost:3200", Ruflet::Rails::DesktopLauncher.backend_url(root: dir, argv: ["server", "-p", "3200"], env: {})
      assert_equal "http://localhost:3300", Ruflet::Rails::DesktopLauncher.backend_url(root: dir, argv: ["s", "--port=3300"], env: {})
    end
  end

  def test_desktop_enabled_by_env_or_flag_not_initializer_file
    Dir.mktmpdir do |dir|
      refute Ruflet::Rails::DesktopLauncher.desktop_enabled?(argv: ["server"], env: {})

      FileUtils.mkdir_p(File.join(dir, "config", "initializers"))
      File.write(File.join(dir, "config", "initializers", "ruflet_desktop.rb"), "")

      refute Ruflet::Rails::DesktopLauncher.desktop_enabled?(argv: ["server"], env: {})
      assert Ruflet::Rails::DesktopLauncher.desktop_enabled?(argv: ["server"], env: { "RUFLET_RAILS_DESKTOP_SERVER" => "true" })
      assert Ruflet::Rails::DesktopLauncher.desktop_enabled?(argv: ["server", "--desktop"], env: {})
    end
  end

  def test_launch_once_can_be_activated_by_desktop_flag_without_initializer
    Dir.mktmpdir do |dir|
      launched = []
      stub_launcher(->(url, root:) { launched << [url, root] }) do
        assert Ruflet::Rails::DesktopLauncher.launch_once(root: dir, argv: ["server", "--desktop"], env: {}, wait: 0)
        sleep 0.05
      end

      assert_equal [["http://localhost:3000", dir]], launched
    end
  end

  def test_launch_once_only_launches_for_activated_rails_server_commands
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "ruflet.yaml"), "app:\n  backend_url: http://localhost:3000\n")

      launched = []
      stub_launcher(->(url, root:) { launched << [url, root] }) do
        assert Ruflet::Rails::DesktopLauncher.launch_once(root: dir, argv: ["server", "-p", "3010"], env: { "RUFLET_RAILS_DESKTOP_SERVER" => "true" }, wait: 0)
        sleep 0.05
        refute Ruflet::Rails::DesktopLauncher.launch_once(root: dir, argv: ["server"], env: { "RUFLET_RAILS_DESKTOP_SERVER" => "true" }, wait: 0)
      end

      assert_equal [["http://localhost:3010", dir]], launched
    end
  end

  def test_launch_once_ignores_console_and_explicit_disable
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config", "initializers"))
      File.write(File.join(dir, "config", "initializers", "ruflet_desktop.rb"), "")

      refute Ruflet::Rails::DesktopLauncher.launch_once(root: dir, argv: ["console"], env: {}, wait: 0)
      refute Ruflet::Rails::DesktopLauncher.launch_once(root: dir, argv: ["server"], env: {}, wait: 0)
      refute Ruflet::Rails::DesktopLauncher.launch_once(root: dir, argv: ["server"], env: { "RUFLET_RAILS_DESKTOP" => "false" }, wait: 0)
    end
  end

  private

  def stub_launcher(callable)
    singleton = class << Ruflet::Rails::DesktopLauncher; self; end
    original = Ruflet::Rails::DesktopLauncher.method(:launch)
    singleton.define_method(:launch) { |url, root:| callable.call(url, root: root) }
    yield
  ensure
    singleton.define_method(:launch) { |url, root:| original.call(url, root: root) } if original
  end
end
