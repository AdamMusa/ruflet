# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"

class RufletCliFlutterSdkTest < Minitest::Test
  class DummySdk
    include Ruflet::CLI::FlutterSdk
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

  def test_desired_flutter_spec_prefers_client_metadata_when_no_fvmrc
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".metadata")
      File.write(path, <<~YAML)
        version:
          revision: "adc901062556672b4138e18a4dc62a4be8f4b3c2"
          channel: "stable"
      YAML

      sdk = DummySdk.new
      spec = sdk.send(:desired_flutter_spec, client_dir: dir)

      assert_equal "adc901062556672b4138e18a4dc62a4be8f4b3c2", spec[:revision]
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

      sdk.define_singleton_method(:which_command) do |name|
        return nil if name == "fvm"
        "/tmp/dart" if name == "dart"
      end
      sdk.define_singleton_method(:system) { |_dart, *_args, **_kwargs| true }

      Dir.stub(:home, dir) do
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

      Dir.stub(:home, dir) do
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

  def test_flutter_host_detects_linux
    sdk = DummySdk.new

    RbConfig::CONFIG.stub(:[], "linux-gnu") do
      assert_equal "linux", sdk.send(:flutter_host)
    end
  end

  def test_flutter_host_detects_windows
    sdk = DummySdk.new

    RbConfig::CONFIG.stub(:[], "mingw32") do
      assert_equal "windows", sdk.send(:flutter_host)
    end
  end
end
