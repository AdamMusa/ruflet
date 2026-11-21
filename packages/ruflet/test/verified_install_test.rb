# frozen_string_literal: true

require_relative "test_helper"
require "digest"
require "fileutils"
require "tmpdir"

class RufletCliVerifiedInstallTest < Minitest::Test
  VerifiedInstall = Ruflet::CLI::VerifiedInstall

  class Extractor
    def initialize(&block)
      @block = block
    end

    def extract_archive(archive, destination)
      @block.call(archive, destination)
    end
  end

  def test_sha256_from_reads_github_and_flutter_digests
    hex = Digest::SHA256.hexdigest("archive")

    assert_equal hex, VerifiedInstall.sha256_from("sha256:#{hex}")
    assert_equal hex, VerifiedInstall.sha256_from(hex.upcase)
    assert_nil VerifiedInstall.sha256_from(nil)
    assert_nil VerifiedInstall.sha256_from("sha512:#{'a' * 128}")
    assert_nil VerifiedInstall.sha256_from("sha256:abc")
  end

  def test_verified_accepts_a_match_and_refuses_a_mismatch
    Dir.mktmpdir do |dir|
      archive = File.join(dir, "a.tar.gz")
      File.binwrite(archive, "archive")

      assert VerifiedInstall.verified?(archive, "sha256:#{Digest::SHA256.hexdigest('archive')}", label: "a.tar.gz")
      _out, err = capture_io { refute VerifiedInstall.verified?(archive, "0" * 64, label: "a.tar.gz") }
      assert_includes err, "a.tar.gz does not match its published SHA-256 (expected #{'0' * 64}, got #{Digest::SHA256.hexdigest('archive')})"
    end
  end

  def test_stage_and_promote_replace_the_destination_only_when_complete
    Dir.mktmpdir do |dir|
      dest = File.join(dir, "web")
      FileUtils.mkdir_p(dest)
      File.write(File.join(dest, "index.html"), "old")
      seen = nil
      extractor = Extractor.new do |_archive, destination|
        seen = File.read(File.join(dest, "index.html"))
        File.write(File.join(destination, "index.html"), "new")
        true
      end

      staging = VerifiedInstall.stage(extractor, "a.tar.gz", dest)
      assert_equal "old", seen, "the destination is untouched while extracting"
      VerifiedInstall.promote(staging, dest)

      assert_equal "new", File.read(File.join(dest, "index.html"))
      assert_equal ["web"], Dir.children(dir)
    end
  end

  def test_a_failed_extraction_leaves_nothing_staged
    Dir.mktmpdir do |dir|
      dest = File.join(dir, "web")
      extractor = Extractor.new do |_archive, destination|
        File.write(File.join(destination, "index.html"), "partial")
        false
      end

      assert_nil VerifiedInstall.stage(extractor, "a.tar.gz", dest)
      assert_empty Dir.children(dir)
    end
  end

  def test_an_interrupted_extraction_leaves_nothing_staged
    Dir.mktmpdir do |dir|
      dest = File.join(dir, "web")
      extractor = Extractor.new do |_archive, destination|
        File.write(File.join(destination, "index.html"), "partial")
        raise Interrupt
      end

      assert_raises(Interrupt) { VerifiedInstall.stage(extractor, "a.tar.gz", dest) }
      assert_empty Dir.children(dir)
    end
  end

  def test_staging_left_by_a_killed_process_is_swept_but_a_live_one_is_kept
    Dir.mktmpdir do |dir|
      dest = File.join(dir, "web")
      dead_pid = Process.spawn("true")
      Process.wait(dead_pid)
      live_pid = Process.spawn("sleep", "30")
      begin
        FileUtils.mkdir_p("#{dest}.partial-#{dead_pid}")
        FileUtils.mkdir_p("#{dest}.old-#{dead_pid}")
        FileUtils.mkdir_p("#{dest}.partial-#{live_pid}")
        FileUtils.mkdir_p("#{dest}-other.partial-#{dead_pid}")

        VerifiedInstall.sweep_abandoned(dest)

        assert_equal ["web-other.partial-#{dead_pid}", "web.partial-#{live_pid}"], Dir.children(dir).sort
      ensure
        Process.kill("KILL", live_pid)
        Process.wait(live_pid)
      end
    end
  end

  def test_human_size
    assert_equal "512 bytes", VerifiedInstall.human_size(512)
    assert_equal "16.3 MB", VerifiedInstall.human_size(17_093_000)
    assert_equal "1.4 GB", VerifiedInstall.human_size(1_503_238_554)
  end
end
