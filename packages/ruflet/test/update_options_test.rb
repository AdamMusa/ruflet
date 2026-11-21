# frozen_string_literal: true

require_relative "test_helper"

# `ruflet update` targets and options, driven through command_update with the
# downloads stubbed.
class RufletCliUpdateOptionsTest < Minitest::Test
  class DummyUpdater
    include Ruflet::CLI::UpdateCommand
  end

  def test_targets_select_which_clients_are_updated
    {
      [] => [:web, :desktop],
      ["all"] => [:web, :desktop],
      ["web"] => [:web],
      ["desktop"] => [:desktop],
      ["WEB"] => [:web],
      ["--web"] => [:web],
      ["--desktop"] => [:desktop],
      ["web", "desktop"] => [:web, :desktop]
    }.each do |argv, expected|
      updater, events = recording_updater
      capture_io { assert_equal 0, updater.command_update(argv.dup), argv.inspect }
      updated = events.select { |event| event.first == :prebuilt }.map { |_, kwargs| kwargs.key?(:web) ? :web : :desktop }
      assert_equal expected, updated, argv.inspect
    end
  end

  def test_force_reaches_the_asset_cache_and_every_client
    updater, events = recording_updater
    capture_io { assert_equal 0, updater.command_update(["--force"]) }

    assert_includes events, [:assets, true]
    prebuilt = events.select { |event| event.first == :prebuilt }
    assert_equal 2, prebuilt.size
    assert(prebuilt.all? { |_, kwargs| kwargs[:force] == true })
  end

  def test_platform_option_overrides_the_host
    updater, events = recording_updater(host: "linux")
    capture_io { assert_equal 0, updater.command_update(["web", "--platform", "Windows"]) }
    assert_equal [[:prebuilt, { web: true, platform: "windows", force: false }]], events.select { |e| e.first == :prebuilt }
  end

  def test_unsupported_platform_or_host_fails_before_downloading
    [[["--platform", "solaris"], "linux"], [[], nil]].each do |argv, host|
      updater, events = recording_updater(host: host)
      _out, err = capture_io { assert_equal 1, updater.command_update(argv.dup), argv.inspect }
      assert_includes err, "Unsupported or missing platform. Use --platform macos|linux|windows."
      assert_empty events
    end
  end

  def test_unknown_target_fails
    updater, events = recording_updater
    _out, err = capture_io { assert_equal 1, updater.command_update(["mobile"]) }
    assert_includes err, "Unknown update target: mobile"
    assert_empty events
  end

  def test_check_positional_and_flag_report_without_downloading
    ["check", "--check"].each do |flag|
      updater, events = check_updater(web: true, desktop: false)
      out, = capture_io { assert_equal 1, updater.command_update([flag]) }
      assert_includes out, "web: installed"
      assert_includes out, "desktop: missing"
      assert_includes out, "Release tag: not installed"
      assert_empty events, flag

      updater, = check_updater(web: true, desktop: false)
      capture_io { assert_equal 0, updater.command_update([flag, "web"]) }
    end
  end

  def test_a_failed_client_download_fails_the_update
    updater, = recording_updater
    updater.define_singleton_method(:ensure_prebuilt_client) { |**_kwargs| nil }
    _out, err = capture_io { assert_equal 1, updater.command_update(["desktop", "--platform", "macos"]) }
    assert_includes err, "Failed to update desktop client for macos"
  end

  private

  def recording_updater(host: "macos")
    updater = DummyUpdater.new
    events = []
    updater.define_singleton_method(:host_platform_name) { host }
    updater.define_singleton_method(:ensure_cached_ruflet_assets_for_update) { |force: false| events << [:assets, force] }
    updater.define_singleton_method(:ensure_flutter!) { |*_args, **_opts| { flutter: "flutter", env: {} } }
    updater.define_singleton_method(:ensure_prebuilt_client) do |**kwargs|
      events << [:prebuilt, kwargs]
      "/tmp/ruflet-cache"
    end
    updater.define_singleton_method(:read_client_manifest) { |_root| { "release_tag" => "v0.0.23" } }
    [updater, events]
  end

  def check_updater(web:, desktop:)
    updater, events = recording_updater
    updater.define_singleton_method(:client_cache_root_for) { |_platform| "/tmp/ruflet-cache" }
    updater.define_singleton_method(:read_client_manifest) { |_root| nil }
    updater.define_singleton_method(:ruflet_version) { "0.0.23" }
    web_present = web
    desktop_present = desktop
    updater.define_singleton_method(:prebuilt_assets_present?) do |_root, web: false, desktop: false, platform: nil|
      web ? web_present : desktop_present
    end
    [updater, events]
  end
end
