# frozen_string_literal: true

require_relative "test_helper"

class RufletCliUpdateCommandTest < Minitest::Test
  class DummyUpdater
    include Ruflet::CLI::UpdateCommand
  end

  def test_command_update_check_reports_manifest_status
    updater = DummyUpdater.new
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "web"))
      File.write(File.join(dir, "web", "index.html"), "<html></html>")

      updater.define_singleton_method(:host_platform_name) { "macos" }
      updater.define_singleton_method(:ruflet_version) { "0.0.8" }
      updater.define_singleton_method(:client_cache_root_for) { |_platform| dir }
      updater.define_singleton_method(:read_client_manifest) do |_root|
        { "release_tag" => "v0.0.8" }
      end
      updater.define_singleton_method(:prebuilt_desktop_present?) { |_root, platform: nil| platform == "macos" }

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      code = updater.command_update(["--check", "--web", "--desktop"])

      assert_equal 0, code
      assert_includes out.string, "Release tag: v0.0.8"
      assert_includes out.string, "web: installed"
      assert_includes out.string, "desktop: installed"
    ensure
      $stdout = original_stdout
    end
  end

  def test_command_update_downloads_requested_target_for_platform
    updater = DummyUpdater.new
    calls = []
    updater.define_singleton_method(:ensure_prebuilt_client) do |**kwargs|
      calls << kwargs
      "/tmp/ruflet-cache"
    end
    updater.define_singleton_method(:read_client_manifest) do |_root|
      { "release_tag" => "v0.0.8" }
    end

    out = StringIO.new
    original_stdout = $stdout
    $stdout = out

    code = updater.command_update(["desktop", "--platform", "linux"])

    assert_equal 0, code
    assert_equal [{ desktop: true, platform: "linux", force: false }], calls
    assert_includes out.string, "Updated desktop client for linux"
  ensure
    $stdout = original_stdout
  end
end
