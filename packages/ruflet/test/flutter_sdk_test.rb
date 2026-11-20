# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"

class RufletCliFlutterSdkTest < Minitest::Test
  class DummySdk
    include Ruflet::CLI::FlutterSdk
  end

  def with_singleton_method(receiver, method_name, implementation)
    singleton = class << receiver; self; end
    original = receiver.method(method_name)
    singleton.send(:define_method, method_name, implementation)
    yield
  ensure
    singleton.send(:define_method, method_name, original)
  end

  def test_parse_fvmrc_json
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".fvmrc")
      File.write(path, "{\"flutter\":\"3.32.5\"}\n")
      assert_equal "3.32.5", DummySdk.new.send(:parse_fvmrc, path)
    end
  end

  def test_parse_fvmrc_plain_text
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".fvmrc")
      File.write(path, "3.29.2\n")
      assert_equal "3.29.2", DummySdk.new.send(:parse_fvmrc, path)
    end
  end

  def test_parse_flutter_metadata_extracts_revision_and_channel
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".metadata")
      File.write(path, <<~YAML)
        version:
          revision: "abc123"
          channel: "stable"
      YAML

      assert_equal(
        { revision: "abc123", channel: "stable" },
        DummySdk.new.send(:parse_flutter_metadata, path)
      )
    end
  end

  def test_desired_flutter_spec_uses_metadata_channel_without_pinning_creation_revision
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".metadata")
      File.write(path, <<~YAML)
        version:
          revision: "adc901062556672b4138e18a4dc62a4be8f4b3c2"
          channel: "stable"
      YAML

      sdk = DummySdk.new
      spec = sdk.send(:desired_flutter_spec, client_dir: dir)

      refute spec.key?(:revision)
      assert_equal "stable", spec[:channel]
      assert_equal :metadata, spec[:source]
    end
  end

  def test_pick_release_matches_by_revision
    manifest = {
      "current_release" => { "stable" => "hash-stable" },
      "releases" => [
        { "hash" => "old", "version" => "3.10.0", "channel" => "stable" },
        { "hash" => "adc901062556672b4138e18a4dc62a4be8f4b3c2", "version" => "3.32.5", "channel" => "stable" }
      ]
    }

    release = DummySdk.new.send(
      :pick_release,
      manifest,
      revision: "adc901062556672b4138e18a4dc62a4be8f4b3c2",
      channel: "stable"
    )

    assert_equal "3.32.5", release["version"]
  end

  def test_ensure_fvm_available_returns_pub_cache_binary_after_activation
    sdk = DummySdk.new

    Dir.mktmpdir do |dir|
      pub_cache_dir = File.join(dir, ".pub-cache", "bin")
      FileUtils.mkdir_p(pub_cache_dir)
      fvm_path = File.join(pub_cache_dir, "fvm")
      File.write(fvm_path, "#!/bin/sh\n")
      FileUtils.chmod("+x", fvm_path)
      dart_path = File.join(dir, "dart")
      File.write(dart_path, "#!/bin/sh\n")
      FileUtils.chmod("+x", dart_path)

      sdk.define_singleton_method(:which_command) do |name|
        return nil if name == "fvm"
        dart_path if name == "dart"
      end
      sdk.define_singleton_method(:system) { |_dart, *_args, **_kwargs| true }

      with_singleton_method(Dir, :home, -> { dir }) do
        assert_equal fvm_path, sdk.send(:ensure_fvm_available)
      end
    end
  end

  def test_tools_from_flutter_bin_exposes_fvm_sdk_environment
    sdk = DummySdk.new

    Dir.mktmpdir do |dir|
      bin_dir = File.join(dir, "bin")
      FileUtils.mkdir_p(bin_dir)
      flutter = File.join(bin_dir, "flutter")
      dart = File.join(bin_dir, "dart")
      File.write(flutter, "#!/bin/sh\n")
      File.write(dart, "#!/bin/sh\n")
      FileUtils.chmod("+x", flutter)
      FileUtils.chmod("+x", dart)

      with_singleton_method(Dir, :home, -> { dir }) do
        tools = sdk.send(:tools_from_flutter_bin, flutter)

        assert_equal flutter, tools[:flutter]
        assert_equal dart, tools[:dart]
        assert_equal dir, tools[:env]["FLUTTER_ROOT"]
        assert_equal dir, tools[:env]["FVM_FLUTTER_SDK"]
        assert_includes tools[:env]["PATH"], bin_dir
        assert_includes tools[:env]["PATH"], File.join(dir, ".pub-cache", "bin")
      end
    end
  end

  def test_flutter_tools_uses_system_flutter_for_unpinned_project
    sdk = DummySdk.new

    Dir.mktmpdir do |dir|
      bin_dir = File.join(dir, "bin")
      FileUtils.mkdir_p(bin_dir)
      flutter = File.join(bin_dir, "flutter")
      dart = File.join(bin_dir, "dart")
      File.write(flutter, "#!/bin/sh\n")
      File.write(dart, "#!/bin/sh\n")
      FileUtils.chmod("+x", flutter)
      FileUtils.chmod("+x", dart)

      sdk.define_singleton_method(:desired_flutter_spec) { |client_dir: nil| { channel: "stable", source: :metadata } }
      sdk.define_singleton_method(:which_command) { |name| name == "flutter" ? flutter : nil }
      sdk.define_singleton_method(:flutter_tools_via_fvm) { |**| flunk "FVM should not run for an unpinned project" }
      sdk.define_singleton_method(:flutter_tools_via_managed_sdk) { |**| flunk "managed SDK should not replace system Flutter" }

      tools = sdk.send(:flutter_tools, client_dir: dir, auto_install: true)

      assert_equal flutter, tools[:flutter]
      assert_equal dart, tools[:dart]
    end
  end

  def test_flutter_tools_falls_back_to_managed_sdk_when_system_flutter_is_unavailable
    sdk = DummySdk.new

    Dir.mktmpdir do |dir|
      sdk_root = File.join(dir, "flutter")
      bin_dir = File.join(sdk_root, "bin")
      FileUtils.mkdir_p(bin_dir)
      flutter = File.join(bin_dir, "flutter")
      dart = File.join(bin_dir, "dart")
      File.write(flutter, "#!/bin/sh\n")
      File.write(dart, "#!/bin/sh\n")
      FileUtils.chmod("+x", flutter)
      FileUtils.chmod("+x", dart)

      sdk.define_singleton_method(:desired_flutter_spec) { |client_dir: nil| { channel: "stable", source: :default } }
      sdk.define_singleton_method(:flutter_tools_via_system) { nil }
      sdk.define_singleton_method(:ensure_flutter_sdk_downloaded) { |client_dir: nil| sdk_root }

      with_singleton_method(Dir, :home, -> { dir }) do
        tools = sdk.send(:flutter_tools, client_dir: nil, auto_install: true)

        assert_equal flutter, tools[:flutter]
        assert_equal dart, tools[:dart]
        assert_equal sdk_root, tools[:env]["FLUTTER_ROOT"]
      end
    end
  end

  # A Flutter SDK where ensure_flutter_sdk_downloaded installs one:
  # <home>/.ruflet/flutter/<version>/<host>/flutter.
  def install_managed_sdk(home, version, host: "macos_arm64")
    sdk_root = File.join(home, ".ruflet", "flutter", version, host, "flutter")
    bin_dir = File.join(sdk_root, "bin")
    FileUtils.mkdir_p(bin_dir)
    %w[flutter dart].each do |tool|
      path = File.join(bin_dir, tool)
      File.write(path, "#!/bin/sh\n")
      FileUtils.chmod("+x", path)
    end
    sdk_root
  end

  # No system Flutter, no FVM, a fixed host, and a network boundary that
  # fails the test unless the test replaces it. The guards raise
  # Minitest::Assertion (via the test's own flunk), which is not a
  # StandardError, so the code's offline `rescue StandardError` cannot
  # swallow them.
  def managed_only_sdk(spec)
    test = self
    sdk = DummySdk.new
    sdk.define_singleton_method(:desired_flutter_spec) { |client_dir: nil| spec }
    sdk.define_singleton_method(:flutter_host) { "macos_arm64" }
    sdk.define_singleton_method(:windows_host?) { false }
    sdk.define_singleton_method(:which_command) { |_name| nil }
    sdk.define_singleton_method(:fetch_releases_manifest) { |_host| test.flunk "the release manifest must not be fetched" }
    sdk.define_singleton_method(:download_file) { |url, _destination| test.flunk "unexpected download of #{url}" }
    sdk
  end

  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end

  def test_flutter_tools_without_auto_install_finds_the_installed_managed_sdk
    Dir.mktmpdir do |home|
      sdk_root = install_managed_sdk(home, "3.41.2")
      sdk = managed_only_sdk({ channel: "stable", source: :metadata })

      with_singleton_method(Dir, :home, -> { home }) do
        tools = sdk.send(:flutter_tools, client_dir: nil, auto_install: false)

        refute_nil tools, "plain `ruflet doctor` must see the SDK `ruflet doctor --fix` installed"
        assert_equal File.join(sdk_root, "bin", "flutter"), tools[:flutter]
        assert_equal sdk_root, tools[:env]["FLUTTER_ROOT"]
      end
    end
  end

  def test_flutter_tools_without_auto_install_and_no_installed_sdk_installs_nothing
    Dir.mktmpdir do |home|
      sdk = managed_only_sdk({ channel: "stable", source: :metadata })

      with_singleton_method(Dir, :home, -> { home }) do
        assert_nil sdk.send(:flutter_tools, client_dir: nil, auto_install: false)
        refute File.exist?(File.join(home, ".ruflet", "flutter"))
      end
    end
  end

  def test_offline_flutter_tools_use_the_installed_managed_sdk
    Dir.mktmpdir do |home|
      sdk_root = install_managed_sdk(home, "3.41.2")
      sdk = managed_only_sdk({ channel: "stable", source: :metadata })
      sdk.define_singleton_method(:fetch_releases_manifest) do |_host|
        raise Errno::ECONNREFUSED, "Failed to open TCP connection"
      end

      with_singleton_method(Dir, :home, -> { home }) do
        tools = nil
        err = capture_stderr { tools = sdk.send(:flutter_tools, client_dir: nil, auto_install: true) }

        refute_nil tools, "an installed SDK must work without the release manifest"
        assert_equal File.join(sdk_root, "bin", "flutter"), tools[:flutter]
        refute_includes err, "auto-install failed"
      end
    end
  end

  def test_unavailable_release_manifest_falls_back_to_the_installed_managed_sdk
    Dir.mktmpdir do |home|
      sdk_root = install_managed_sdk(home, "3.41.2")
      sdk = managed_only_sdk({ channel: "stable", source: :metadata })
      sdk.define_singleton_method(:fetch_releases_manifest) { |_host| nil }

      with_singleton_method(Dir, :home, -> { home }) do
        assert_equal sdk_root, sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil)
      end
    end
  end

  def test_offline_without_an_installed_sdk_still_reports_the_failure
    Dir.mktmpdir do |home|
      sdk = managed_only_sdk({ channel: "stable", source: :metadata })
      sdk.define_singleton_method(:fetch_releases_manifest) do |_host|
        raise Errno::ECONNREFUSED, "Failed to open TCP connection"
      end

      with_singleton_method(Dir, :home, -> { home }) do
        result = :unset
        err = capture_stderr { result = sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil) }

        assert_nil result
        assert_includes err, "Flutter auto-install failed: Errno::ECONNREFUSED"
      end
    end
  end

  def test_installed_managed_sdk_prefers_the_pinned_version
    Dir.mktmpdir do |home|
      install_managed_sdk(home, "3.38.0")
      pinned = install_managed_sdk(home, "3.41.2")
      install_managed_sdk(home, "3.44.0")
      sdk = managed_only_sdk({ version: "3.41.2", source: :env })

      with_singleton_method(Dir, :home, -> { home }) do
        assert_equal pinned, sdk.send(:installed_managed_flutter_sdk_root)
      end
    end
  end

  def test_installed_managed_sdk_never_replaces_a_pinned_version_that_is_not_installed
    Dir.mktmpdir do |home|
      install_managed_sdk(home, "3.38.0")
      sdk = managed_only_sdk({ version: "3.41.2", source: :fvmrc })

      with_singleton_method(Dir, :home, -> { home }) do
        assert_nil sdk.send(:installed_managed_flutter_sdk_root)
      end
    end
  end

  def test_installed_managed_sdk_matches_a_pin_with_a_channel_suffix
    Dir.mktmpdir do |home|
      pinned = install_managed_sdk(home, "3.41.2")
      install_managed_sdk(home, "3.44.0")
      sdk = managed_only_sdk({ version: "3.41.2@stable", source: :fvmrc })

      with_singleton_method(Dir, :home, -> { home }) do
        assert_equal pinned, sdk.send(:installed_managed_flutter_sdk_root)
      end
    end
  end

  def test_installed_managed_sdk_prefers_the_newest_prerelease_off_the_stable_channel
    Dir.mktmpdir do |home|
      install_managed_sdk(home, "3.41.2")
      prerelease = install_managed_sdk(home, "3.44.0-0.1.pre")
      sdk = managed_only_sdk({ channel: "beta", source: :metadata })

      with_singleton_method(Dir, :home, -> { home }) do
        assert_equal prerelease, sdk.send(:installed_managed_flutter_sdk_root)
      end
    end
  end

  def test_installed_managed_sdk_picks_the_newest_stable_without_a_pin
    Dir.mktmpdir do |home|
      # 3.10.0 sorts first as a string and 3.9.0 sorts last, so neither
      # string order nor directory order can pick 3.41.2 by accident.
      install_managed_sdk(home, "3.10.0")
      install_managed_sdk(home, "3.9.0")
      newest = install_managed_sdk(home, "3.41.2")
      install_managed_sdk(home, "3.44.0-0.1.pre")
      install_managed_sdk(home, "3.50.0", host: "linux")
      FileUtils.mkdir_p(File.join(home, ".ruflet", "flutter", "3.60.0", "macos_arm64"))
      sdk = managed_only_sdk({ channel: "stable", source: :metadata })

      with_singleton_method(Dir, :home, -> { home }) do
        assert_equal newest, sdk.send(:installed_managed_flutter_sdk_root)
      end
    end
  end

  def test_online_resolution_still_downloads_the_resolved_release
    Dir.mktmpdir do |home|
      install_managed_sdk(home, "3.41.2")
      sdk = managed_only_sdk({ channel: "stable", source: :metadata })
      sdk.define_singleton_method(:fetch_releases_manifest) do |_host|
        {
          "current_release" => { "stable" => "new" },
          "releases" => [
            { "hash" => "old", "channel" => "stable", "version" => "3.41.2", "archive" => "stable/macos/flutter_macos_arm64_3.41.2-stable.zip" },
            { "hash" => "new", "channel" => "stable", "version" => "3.44.0", "archive" => "stable/macos/flutter_macos_arm64_3.44.0-stable.zip" }
          ]
        }
      end
      downloads = []
      sdk.define_singleton_method(:download_file) { |url, destination| downloads << url; destination }
      sdk.define_singleton_method(:extract_archive) do |_archive, destination|
        flutter = File.join(destination, "flutter", "bin", "flutter")
        FileUtils.mkdir_p(File.dirname(flutter))
        File.write(flutter, "#!/bin/sh\n")
        FileUtils.chmod("+x", flutter)
        true
      end

      with_singleton_method(Dir, :home, -> { home }) do
        sdk_root = sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil)

        assert_equal File.join(home, ".ruflet", "flutter", "3.44.0", "macos_arm64", "flutter"), sdk_root
        assert_equal ["#{Ruflet::CLI::FlutterSdk::RELEASES_BASE}/stable/macos/flutter_macos_arm64_3.44.0-stable.zip"], downloads
      end
    end
  end

  def test_flutter_host_detects_linux
    sdk = DummySdk.new

    with_singleton_method(RbConfig::CONFIG, :[], ->(key) { key == "host_os" ? "linux-gnu" : nil }) do
      assert_equal "linux", sdk.send(:flutter_host)
    end
  end

  def test_flutter_host_detects_windows
    sdk = DummySdk.new

    with_singleton_method(RbConfig::CONFIG, :[], ->(key) { key == "host_os" ? "mingw32" : nil }) do
      assert_equal "windows", sdk.send(:flutter_host)
    end
  end
end
