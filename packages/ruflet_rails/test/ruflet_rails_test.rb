# frozen_string_literal: true

require_relative "test_helper"

class RufletRailsTest < Minitest::Test
  def test_loads_local_sibling_ruflet_first
    loaded_ruflet = $LOADED_FEATURES.find { |path| path.end_with?("/ruflet_core/lib/ruflet_core.rb") }
    expected = File.expand_path("../../ruflet_core/lib/ruflet_core.rb", __dir__)

    assert_equal expected, loaded_ruflet
  end

  def test_app_loader_captures_ruflet_run_entrypoint_for_rails
    app_file = nil

    Dir.mktmpdir do |dir|
      class_name = "LoaderCaptureApp#{SecureRandom.hex(4)}"
      app_file = File.join(dir, "main.rb")

      File.write(app_file, <<~RUBY)
        require "ruflet"

        class #{class_name} < Ruflet::App
          def view(_page); end
        end

        #{class_name}.new.run
      RUBY

      loaded = Ruflet::Rails::Protocol::MobileLoader.new(app_file).load!

      assert loaded.is_a?(Hash)
      assert loaded[:entrypoint].respond_to?(:call)
    end
  ensure
    File.delete(app_file) if app_file && File.exist?(app_file)
  end

  def test_endpoint_without_an_entry_raises
    # A bare endpoint has no auto-discovery fallback — the developer must
    # declare an app file or a block.
    error = assert_raises(ArgumentError) { Ruflet::Rails.endpoint }
    assert_match(/requires one of app_file: or a block/, error.message)
  end

  def test_configuration_serializes_declared_extensions
    config = Ruflet::Rails::Configuration.new
    config.extensions = %w[webview]

    assert_equal %w[webview], config.to_ruflet_yaml_hash["extensions"]
  end

  def test_configuration_omits_empty_services_and_extensions
    config = Ruflet::Rails::Configuration.new

    yaml_hash = config.to_ruflet_yaml_hash

    refute_includes yaml_hash, "services"
    refute_includes yaml_hash, "extensions"
  end

end
