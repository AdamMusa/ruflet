# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

local_lib = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(local_lib) unless $LOAD_PATH.include?(local_lib)

require "generators/ruflet/install/install_generator"

class RufletInstallGeneratorTest < Minitest::Test
  def test_desktop_option_requests_desktop_client
    generator = build_generator(desktop: true)

    assert_equal "desktop", generator.send(:requested_client)
    assert generator.send(:desktop_requested?)
  end

  def test_no_options_requests_no_client
    generator = build_generator({})

    assert_equal "none", generator.send(:requested_client)
    refute generator.send(:desktop_requested?)
  end

  def test_client_option_overrides_desktop_flag
    generator = build_generator(desktop: true, client: "none")

    assert_equal "none", generator.send(:requested_client)
    refute generator.send(:desktop_requested?)
  end

  def test_web_and_desktop_options_request_all_clients
    generator = build_generator(web: true, desktop: true)

    assert_equal "all", generator.send(:requested_client)
    assert generator.send(:desktop_requested?)
    assert generator.send(:web_requested?)
  end

  def test_web_option_installs_web_client_into_the_rails_app
    generator = build_generator(web: true)
    installed_root = nil
    original = Ruflet::Rails::WebInstaller.method(:install!)
    Ruflet::Rails::WebInstaller.define_singleton_method(:install!) do |root:, **|
      installed_root = root
      true
    end

    capture_io { generator.download_prebuilt_client }

    assert_equal Dir.pwd, installed_root
  ensure
    Ruflet::Rails::WebInstaller.define_singleton_method(:install!, original)
  end

  def test_install_generator_only_creates_the_ruflet_entrypoint
    generator = build_generator({})

    refute generator.respond_to?(:create_application_component)
  end

  def test_install_mounts_the_websocket_route_explicitly
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config", "routes.rb"), "Rails.application.routes.draw do\nend\n")

      generator = Ruflet::Generators::InstallGenerator.new([], {}, destination_root: dir)
      capture_io { generator.invoke_all }

      routes = File.read(File.join(dir, "config", "routes.rb"))
      assert_includes routes,
                      'match "/ws", to: Ruflet::Rails.native(Rails.root.join("app/views/ruflet/main.rb")), via: :all',
                      "the generator should mount /ws explicitly — no Railtie auto-mount magic"
    end
  end

  def test_install_does_not_duplicate_the_websocket_route
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config", "routes.rb"), "Rails.application.routes.draw do\nend\n")

      generator = Ruflet::Generators::InstallGenerator.new([], {}, destination_root: dir)
      capture_io { generator.invoke_all }
      generator2 = Ruflet::Generators::InstallGenerator.new([], {}, destination_root: dir)
      capture_io { generator2.invoke_all }

      assert_equal 1, File.read(File.join(dir, "config", "routes.rb")).scan("Ruflet::Rails.native(").length
    end
  end

  def test_web_install_mounts_only_the_generated_app_at_ruflet
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config", "routes.rb"), "Rails.application.routes.draw do\nend\n")

      generator = Ruflet::Generators::InstallGenerator.new([], { "web" => true }, destination_root: dir)
      capture_io { generator.mount_websocket }
      capture_io { generator.mount_web_app }

      routes = File.read(File.join(dir, "config", "routes.rb"))
      assert_includes routes,
                      'mount Ruflet::Rails.web(app_file: Rails.root.join("app/views/ruflet/main.rb")), at: "/ruflet"'
      refute_includes routes, "/products"
    end
  end

  def test_install_creates_ruflet_initializer_for_build_config
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config", "routes.rb"), "Rails.application.routes.draw do\nend\n")

      generator = Ruflet::Generators::InstallGenerator.new([], {}, destination_root: dir)
      capture_io { generator.invoke_all }

      initializer = File.join(dir, "config", "initializers", "ruflet.rb")
      assert File.exist?(initializer)
      assert_includes File.read(initializer), "Ruflet::Rails.configure"
      assert_includes File.read(initializer), "config.backend_url"
      assert File.exist?(File.join(dir, "app", "views", "ruflet", "main.rb"))
      refute File.exist?(File.join(dir, "ruflet.yaml"))
    end
  end

  def test_desktop_install_patches_ruby_rails_binstub_and_shell_dev_binstub
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "bin"))
      File.write(File.join(dir, "bin", "rails"), "#!/usr/bin/env ruby\nAPP_PATH = File.expand_path('../config/application', __dir__)\n")
      File.write(File.join(dir, "bin", "dev"), "#!/usr/bin/env sh\nexec foreman start -f Procfile.dev \"$@\"\n")

      generator = Ruflet::Generators::InstallGenerator.new([], { "desktop" => true }, destination_root: dir)
      capture_io { generator.add_desktop_flag_to_binstubs }

      rails = File.read(File.join(dir, "bin", "rails"))
      dev = File.read(File.join(dir, "bin", "dev"))
      assert_includes rails, 'ARGV.delete("--desktop")'
      assert_includes rails, 'ENV["RUFLET_RAILS_DESKTOP"] = "true"'
      assert_includes rails, 'ENV["RUFLET_RAILS_DESKTOP_SERVER"] = "true"'
      assert_includes dev, '[ "$1" = "--desktop" ]'
      assert_includes dev, "export RUFLET_RAILS_DESKTOP=true"
      assert_includes dev, "export RUFLET_RAILS_DESKTOP_SERVER=true"
    end
  end

  private

  def build_generator(options)
    string_options = options.each_with_object({}) do |(key, value), values|
      values[key.to_s] = value
    end
    Ruflet::Generators::InstallGenerator.new([], string_options, destination_root: Dir.pwd)
  end
end
