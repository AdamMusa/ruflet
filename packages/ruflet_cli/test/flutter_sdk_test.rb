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
end
