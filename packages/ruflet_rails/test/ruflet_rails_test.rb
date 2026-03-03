# frozen_string_literal: true

require_relative "test_helper"

class RufletRailsTest < Minitest::Test
  def test_loads_local_sibling_ruflet_first
    loaded_ruflet = $LOADED_FEATURES.find { |path| path.end_with?("/ruflet/lib/ruflet.rb") }
    expected = File.expand_path("../../ruflet/lib/ruflet.rb", __dir__)

    assert_equal expected, loaded_ruflet
  end

  def test_mobile_loader_captures_entrypoint_without_ruflet_server
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
end
