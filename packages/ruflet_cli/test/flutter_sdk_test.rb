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
end
