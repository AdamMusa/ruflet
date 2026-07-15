# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"

class RufletAssetServingTest < Minitest::Test
  def test_resolves_assets_from_configured_project_assets_directory
    server = Ruflet::Server.new

    Dir.mktmpdir do |dir|
      assets = File.join(dir, "assets")
      FileUtils.mkdir_p(assets)
      icon = File.join(assets, "icon.png")
      File.binwrite(icon, "png")

      previous = ENV["RUFLET_ASSETS_DIR"]
      ENV["RUFLET_ASSETS_DIR"] = assets
      begin
        assert_equal icon, server.send(:resolve_asset_path, "/assets/icon.png")
        assert_equal "png", server.send(:read_binary_file, icon)
        assert_nil server.send(:resolve_asset_path, "/assets/../main.rb")
        assert_nil server.send(:resolve_asset_path, "/not-assets/icon.png")
      ensure
        ENV["RUFLET_ASSETS_DIR"] = previous
      end
    end
  end
end
