# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "digest"

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
    # The size in the download notice is optional; never ask the network.
    sdk.define_singleton_method(:remote_file_size) { |_url| nil }
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

  # --- installing a downloaded SDK -------------------------------------------

  ARCHIVE_BYTES = ("flutter sdk archive " * 4096).freeze

  def stable_manifest(version: "3.44.0", sha256: Digest::SHA256.hexdigest(ARCHIVE_BYTES), arch: "arm64")
    {
      "current_release" => { "stable" => "new" },
      "releases" => [
        {
          "hash" => "new", "channel" => "stable", "version" => version, "dart_sdk_arch" => arch,
          "archive" => "stable/macos/flutter_macos_arm64_#{version}-stable.zip", "sha256" => sha256
        }
      ]
    }
  end

  # Downloads write ARCHIVE_BYTES (or `bytes`); extraction lays out an SDK
  # the way a release archive does, a top-level flutter/ directory.
  def downloading_sdk(spec, manifest: stable_manifest, bytes: ARCHIVE_BYTES, extract_ok: true)
    sdk = managed_only_sdk(spec)
    calls = { downloads: [], extracted_into: [] }
    sdk.define_singleton_method(:fetch_releases_manifest) { |_host| manifest }
    sdk.define_singleton_method(:download_file) do |url, destination|
      calls[:downloads] << url
      File.binwrite(destination, bytes)
      destination
    end
    sdk.define_singleton_method(:extract_archive) do |_archive, destination|
      calls[:extracted_into] << destination
      flutter = File.join(destination, "flutter", "bin", "flutter")
      FileUtils.mkdir_p(File.dirname(flutter))
      File.write(flutter, "#!/bin/sh\n")
      FileUtils.chmod("+x", flutter)
      extract_ok
    end
    [sdk, calls]
  end

  def managed_root(home, version, host: "macos_arm64")
    File.join(home, ".ruflet", "flutter", version, host)
  end

  def test_a_verified_sdk_download_is_staged_and_marked_complete
    Dir.mktmpdir do |home|
      sdk, calls = downloading_sdk({ channel: "stable", source: :metadata })

      with_singleton_method(Dir, :home, -> { home }) do
        sdk_root = nil
        out, err = capture_io { sdk_root = sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil) }

        install_root = managed_root(home, "3.44.0")
        assert_equal File.join(install_root, "flutter"), sdk_root
        assert File.file?(File.join(install_root, ".ruflet-complete"))
        refute File.exist?(File.join(install_root, "flutter", ".ruflet-complete")), "the marker stays out of the SDK checkout"
        refute_includes calls[:extracted_into], install_root, "extraction must not write into the live install"
        assert_equal ["macos_arm64"], Dir.children(File.dirname(install_root)), "no staging directory is left behind"
        # On stderr: stdout may be Flutter's own (`ruflet devices --machine`).
        refute_includes out, "Downloading Flutter"
        assert_includes err, "Downloading Flutter 3.44.0 to #{install_root}. To use your own SDK, put flutter on PATH, " \
                             "or pin a version with RUFLET_FLUTTER_VERSION or .fvmrc."
        refute_includes err, "No SHA-256"

        # Installed: the next run downloads nothing.
        assert_equal sdk_root, sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil)
        assert_equal 1, calls[:downloads].length
      end
    end
  end

  def test_the_download_notice_gives_the_archive_size
    Dir.mktmpdir do |home|
      sdk, = downloading_sdk({ channel: "stable", source: :metadata })
      sdk.define_singleton_method(:remote_file_size) { |_url| 1_503_238_554 }

      with_singleton_method(Dir, :home, -> { home }) do
        _out, err = capture_io { sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil) }

        assert_includes err, "Downloading Flutter 3.44.0 (1.4 GB) to #{managed_root(home, '3.44.0')}."
      end
    end
  end

  # A pin is never satisfied by the flutter on PATH, so the notice does not
  # suggest it (or suggest pinning) when RUFLET_FLUTTER_VERSION or .fvmrc is set.
  def test_the_download_notice_for_a_pinned_version_gives_no_hint
    %i[env fvmrc].each do |source|
      Dir.mktmpdir do |home|
        sdk, = downloading_sdk({ version: "3.44.0", source: source })

        with_singleton_method(Dir, :home, -> { home }) do
          _out, err = capture_io { sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil) }

          notice = err.lines.grep(/Downloading Flutter/)
          assert_equal ["Downloading Flutter 3.44.0 to #{managed_root(home, '3.44.0')}.\n"], notice, source.to_s
        end
      end
    end
  end

  # The install that got there first wins: a second process finishing the
  # same download must not move an SDK a running build uses out of the way.
  def test_an_install_finished_meanwhile_by_another_process_is_kept
    Dir.mktmpdir do |home|
      test = self
      sdk, calls = downloading_sdk({ channel: "stable", source: :metadata })
      install_root = managed_root(home, "3.44.0")
      stage_extract = sdk.method(:extract_archive)
      sdk.define_singleton_method(:extract_archive) do |archive, destination|
        other = test.install_managed_sdk(home, "3.44.0")
        File.write(File.join(other, "in-use"), "the other process's SDK")
        File.write(File.join(install_root, ".ruflet-complete"), "{\"by\": \"the other process\"}")
        stage_extract.call(archive, destination)
      end

      with_singleton_method(Dir, :home, -> { home }) do
        sdk_root = nil
        capture_io { sdk_root = sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil) }

        assert_equal File.join(install_root, "flutter"), sdk_root
        assert_equal 1, calls[:extracted_into].length
        assert_equal "the other process's SDK", File.read(File.join(install_root, "flutter", "in-use"))
        assert_equal "{\"by\": \"the other process\"}", File.read(File.join(install_root, ".ruflet-complete"))
        assert_equal ["macos_arm64"], Dir.children(File.dirname(install_root)), "the staged copy is removed"
      end
    end
  end

  # A download cut short used to be extracted in place, and the bin/flutter
  # it left counted as installed on every later run and offline.
  def test_a_truncated_sdk_download_is_refused_by_its_sha256
    Dir.mktmpdir do |home|
      sdk, calls = downloading_sdk({ channel: "stable", source: :metadata }, bytes: ARCHIVE_BYTES[0, 1000])

      with_singleton_method(Dir, :home, -> { home }) do
        result = :unset
        _out, err = capture_io { result = sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil) }

        assert_nil result
        assert_includes err, "flutter_macos_arm64_3.44.0-stable.zip does not match its published SHA-256"
        assert_empty calls[:extracted_into]
        refute File.exist?(managed_root(home, "3.44.0"))
        assert_nil sdk.send(:installed_managed_flutter_sdk_root)
      end
    end
  end

  def test_a_failed_sdk_extraction_is_never_installed
    Dir.mktmpdir do |home|
      sdk, calls = downloading_sdk({ channel: "stable", source: :metadata }, extract_ok: false)

      with_singleton_method(Dir, :home, -> { home }) do
        2.times do
          result = :unset
          _out, err = capture_io { result = sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil) }

          assert_nil result
          assert_includes err, "Failed to extract flutter_macos_arm64_3.44.0-stable.zip"
        end
        assert_equal 2, calls[:downloads].length, "a failed install is retried, not accepted"
        refute File.exist?(managed_root(home, "3.44.0"))
        assert_nil sdk.send(:installed_managed_flutter_sdk_root), "the offline path must not accept it either"
        assert_equal [], Dir.children(File.join(home, ".ruflet", "flutter", "3.44.0"))
      end
    end
  end

  def test_an_sdk_without_a_published_sha256_installs_with_a_warning
    Dir.mktmpdir do |home|
      sdk, = downloading_sdk({ channel: "stable", source: :metadata }, manifest: stable_manifest(sha256: nil))

      with_singleton_method(Dir, :home, -> { home }) do
        sdk_root = nil
        _out, err = capture_io { sdk_root = sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil) }

        assert_equal File.join(managed_root(home, "3.44.0"), "flutter"), sdk_root
        assert_includes err, "No SHA-256 is published for flutter_macos_arm64_3.44.0-stable.zip; installing it unverified"
      end
    end
  end

  # With 3.41.2 installed and no pin, a newer stable that fails to download
  # made ensure_flutter! exit 1.
  def test_a_failed_download_of_a_newer_sdk_uses_the_installed_one
    Dir.mktmpdir do |home|
      installed = install_managed_sdk(home, "3.41.2")
      sdk, = downloading_sdk({ channel: "stable", source: :metadata })
      sdk.define_singleton_method(:download_file) { |_url, _destination| raise Errno::ECONNRESET, "simulated" }

      with_singleton_method(Dir, :home, -> { home }) do
        tools = nil
        exited = nil
        _out, err = capture_io do
          tools = sdk.ensure_flutter!("build", client_dir: nil)
        rescue SystemExit => e
          exited = e.status
        end

        assert_nil exited, "ensure_flutter! must not exit while an SDK is installed"

        assert_equal File.join(installed, "bin", "flutter"), tools[:flutter]
        assert_includes err, "Flutter auto-install failed: Errno::ECONNRESET"
        assert_includes err, "Using the Flutter SDK already installed at #{installed}"
        refute File.exist?(managed_root(home, "3.44.0"))
      end
    end
  end

  def test_a_failed_download_of_a_pinned_sdk_does_not_substitute_another_version
    Dir.mktmpdir do |home|
      install_managed_sdk(home, "3.41.2")
      sdk, = downloading_sdk({ version: "3.44.0", source: :env })
      sdk.define_singleton_method(:download_file) { |_url, _destination| raise Errno::ECONNRESET, "simulated" }

      with_singleton_method(Dir, :home, -> { home }) do
        result = :unset
        _out, err = capture_io { result = sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil) }

        assert_nil result
        refute_includes err, "Using the Flutter SDK already installed"
      end
    end
  end

  # SDKs installed before installs were marked complete carry no marker.
  def test_an_unmarked_sdk_is_accepted_once_flutter_version_works
    Dir.mktmpdir do |home|
      sdk_root = install_managed_sdk(home, "3.41.2")
      sdk = managed_only_sdk({ channel: "stable", source: :metadata })

      with_singleton_method(Dir, :home, -> { home }) do
        assert_equal sdk_root, sdk.send(:installed_managed_flutter_sdk_root)
        assert File.file?(File.join(managed_root(home, "3.41.2"), ".ruflet-complete"))
      end
    end
  end

  def test_an_unmarked_sdk_whose_flutter_fails_is_ignored
    Dir.mktmpdir do |home|
      older = install_managed_sdk(home, "3.38.0")
      partial = install_managed_sdk(home, "9.9.9")
      File.write(File.join(partial, "bin", "flutter"), "#!/bin/sh\nexit 1\n")
      sdk = managed_only_sdk({ channel: "stable", source: :metadata })

      with_singleton_method(Dir, :home, -> { home }) do
        result = nil
        _out, err = capture_io { result = sdk.send(:installed_managed_flutter_sdk_root) }

        assert_equal older, result
        assert_includes err, "Ignoring the Flutter SDK at #{partial}: `flutter --version` fails there, so it may be a partial install"
        assert File.file?(File.join(managed_root(home, "9.9.9"), ".ruflet-incomplete"))

        # Checked once: later runs skip it without running it again.
        _out, err = capture_io { result = sdk.send(:installed_managed_flutter_sdk_root) }
        assert_equal older, result
        assert_empty err
      end
    end
  end

  def test_the_check_of_an_unmarked_sdk_gives_up_on_a_flutter_that_hangs
    Dir.mktmpdir do |dir|
      flutter = File.join(dir, "flutter")
      File.write(flutter, "#!/bin/sh\nexec sleep 30\n")
      FileUtils.chmod("+x", flutter)

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      refute DummySdk.new.send(:legacy_flutter_sdk_works?, flutter, timeout: 0.3)
      assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 10
    end
  end

  # bin/flutter is a shell script; what it starts (a tool rebuild, a Dart
  # SDK fetch) must not outlive the check.
  def test_the_check_of_an_unmarked_sdk_also_stops_what_flutter_started
    Dir.mktmpdir do |dir|
      child_pid_file = File.join(dir, "child.pid")
      flutter = File.join(dir, "flutter")
      File.write(flutter, "#!/bin/sh\nsleep 30 &\necho $! > '#{child_pid_file}'\nwait\n")
      FileUtils.chmod("+x", flutter)

      refute DummySdk.new.send(:legacy_flutter_sdk_works?, flutter, timeout: 2)
      child = Integer(File.read(child_pid_file).strip, 10)
      if Ruflet::CLI::VerifiedInstall.process_alive?(child)
        Process.kill("KILL", child)
        flunk "the child flutter started (#{child}) still runs after the check"
      end
    end
  end

  def test_the_check_of_an_unmarked_sdk_stops_flutter_when_interrupted
    Dir.mktmpdir do |dir|
      pid_file = File.join(dir, "flutter.pid")
      flutter = File.join(dir, "flutter")
      File.write(flutter, "#!/bin/sh\necho $$ > '#{pid_file}'\nexec sleep 30\n")
      FileUtils.chmod("+x", flutter)
      sdk = DummySdk.new
      sdk.define_singleton_method(:sleep) do |_seconds|
        raise Interrupt if File.size?(pid_file)

        Kernel.sleep(0.05)
      end

      assert_raises(Interrupt) { sdk.send(:legacy_flutter_sdk_works?, flutter, timeout: 10) }
      flutter_pid = Integer(File.read(pid_file).strip, 10)
      if Ruflet::CLI::VerifiedInstall.process_alive?(flutter_pid)
        Process.kill("KILL", flutter_pid)
        Process.wait(flutter_pid)
        flunk "flutter (#{flutter_pid}) still runs after Ctrl-C"
      end
    end
  end

  def test_a_fresh_download_replaces_an_incomplete_install_of_the_same_version
    Dir.mktmpdir do |home|
      partial = install_managed_sdk(home, "3.44.0")
      File.write(File.join(partial, "bin", "flutter"), "#!/bin/sh\nexit 1\n")
      File.write(File.join(partial, "leftover"), "from the interrupted extraction")
      sdk, calls = downloading_sdk({ channel: "stable", source: :metadata })

      with_singleton_method(Dir, :home, -> { home }) do
        sdk_root = nil
        capture_io { sdk_root = sdk.send(:ensure_flutter_sdk_downloaded, client_dir: nil) }

        assert_equal partial, sdk_root
        assert_equal 1, calls[:downloads].length
        refute File.exist?(File.join(partial, "leftover"))
        assert File.file?(File.join(managed_root(home, "3.44.0"), ".ruflet-complete"))
        refute File.exist?(File.join(managed_root(home, "3.44.0"), ".ruflet-incomplete"))
        assert_equal ["macos_arm64"], Dir.children(File.join(home, ".ruflet", "flutter", "3.44.0"))
      end
    end
  end

  def test_an_unpinned_lookup_prints_no_stable_not_found_warning
    manifest = {
      "current_release" => { "stable" => "new" },
      "releases" => [
        { "hash" => "new", "channel" => "stable", "version" => "3.44.0" },
        { "hash" => "old", "channel" => "stable", "version" => "3.41.2" }
      ]
    }
    release = nil
    _out, err = capture_io do
      release = DummySdk.new.send(:pick_release, manifest, version: "stable", channel: "stable")
    end

    assert_equal "3.44.0", release["version"]
    assert_empty err
  end

  # Flutter has no releases_macos_arm64.json (it returns 404), so the managed
  # SDK never installed on Apple Silicon. releases_macos.json lists both
  # architectures, x64 first.
  def macos_manifest
    {
      "current_release" => { "stable" => "new" },
      "releases" => [
        { "hash" => "new", "channel" => "stable", "version" => "3.50.1", "dart_sdk_arch" => "x64",
          "archive" => "stable/macos/flutter_macos_3.50.1-stable.zip", "sha256" => "a" * 64 },
        { "hash" => "new", "channel" => "stable", "version" => "3.50.1", "dart_sdk_arch" => "arm64",
          "archive" => "stable/macos/flutter_macos_arm64_3.50.1-stable.zip", "sha256" => "b" * 64 },
        { "hash" => "old", "channel" => "stable", "version" => "2.10.5",
          "archive" => "stable/macos/flutter_macos_2.10.5-stable.zip", "sha256" => "c" * 64 }
      ]
    }
  end

  def test_apple_silicon_reads_the_macos_manifest_and_picks_the_arm64_archive
    sdk = managed_only_sdk({ channel: "stable", source: :metadata })
    hosts = []
    manifest = macos_manifest
    sdk.define_singleton_method(:fetch_releases_manifest) { |host| hosts << host; manifest }

    info = sdk.send(:resolve_flutter_release)

    assert_equal ["macos"], hosts
    assert_equal "macos_arm64", info[:host]
    assert_equal "stable/macos/flutter_macos_arm64_3.50.1-stable.zip", info[:release]["archive"]
  end

  def test_an_intel_mac_keeps_the_x64_archive
    sdk = managed_only_sdk({ channel: "stable", source: :metadata })
    sdk.define_singleton_method(:flutter_host) { "macos" }
    manifest = macos_manifest
    manifest["releases"][0], manifest["releases"][1] = manifest["releases"][1], manifest["releases"][0]
    sdk.define_singleton_method(:fetch_releases_manifest) { |_host| manifest }

    info = sdk.send(:resolve_flutter_release)

    assert_equal "stable/macos/flutter_macos_3.50.1-stable.zip", info[:release]["archive"]
  end

  def test_windows_extraction_quotes_paths_with_an_apostrophe
    sdk = DummySdk.new
    sdk.define_singleton_method(:windows_host?) { true }
    commands = []
    sdk.define_singleton_method(:system) { |*args| commands << args; true }

    assert sdk.send(:extract_archive, "C:\\Users\\O'Brien\\Temp\\ruflet [1]\\client.zip", "C:\\Users\\O'Brien\\.ruflet\\client")

    assert_equal [[
      "powershell", "-NoProfile", "-Command",
      "Expand-Archive -LiteralPath 'C:\\Users\\O''Brien\\Temp\\ruflet [1]\\client.zip' " \
      "-DestinationPath 'C:\\Users\\O''Brien\\.ruflet\\client' -Force"
    ]], commands
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
