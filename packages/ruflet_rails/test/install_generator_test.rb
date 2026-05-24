# frozen_string_literal: true

require_relative "test_helper"

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
  end

  private

  def build_generator(options)
    string_options = options.each_with_object({}) do |(key, value), values|
      values[key.to_s] = value
    end
    Ruflet::Generators::InstallGenerator.new([], string_options, destination_root: Dir.pwd)
  end
end
