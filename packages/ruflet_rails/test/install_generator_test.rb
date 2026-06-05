# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

local_lib = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(local_lib) unless $LOAD_PATH.include?(local_lib)

require "generators/ruflet/install/install_generator"

class RufletInstallGeneratorTest < Minitest::Test
  def test_web_option_requests_web_client
    generator = build_generator(web: true)

    assert_equal "web", generator.send(:requested_client)
  end

  def test_desktop_option_requests_desktop_client
    generator = build_generator(desktop: true)

    assert_equal "desktop", generator.send(:requested_client)
    assert generator.send(:desktop_requested?)
  end

  def test_web_and_desktop_options_request_all_clients
    generator = build_generator(web: true, desktop: true)

    assert_equal "all", generator.send(:requested_client)
  end

  def test_client_option_remains_backward_compatible
    generator = build_generator(client: "web")

    assert_equal "web", generator.send(:requested_client)
  end

  def test_client_option_overrides_web_and_desktop_flags
    generator = build_generator(web: true, desktop: true, client: "none")

    assert_equal "none", generator.send(:requested_client)
    refute generator.send(:desktop_requested?)
  end

  def test_install_generator_does_not_create_component_glue
    generator = build_generator({})

    refute generator.respond_to?(:create_application_component)
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
