# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"

class RufletWebInstallerTest < Minitest::Test
  def test_install_extracts_prebuilt_web_client_into_frontend
    Dir.mktmpdir do |root|
      tarball = build_fake_web_tarball(root)

      with_stubs(
        release_asset_url: ->(*) { "https://example/ruflet_client-web.tar.gz" },
        download: ->(_url, path) { FileUtils.cp(tarball, path); true }
      ) do
        assert Ruflet::Rails::WebInstaller.install!(root: root)
      end

      assert File.file?(File.join(root, "frontend", "index.html"))
      assert File.file?(File.join(root, "frontend", "main.dart.js"))
    end
  end

  def test_install_returns_false_when_release_asset_is_missing
    Dir.mktmpdir do |root|
      with_stubs(release_asset_url: ->(*) { nil }) do
        refute Ruflet::Rails::WebInstaller.install!(root: root)
      end
      refute Dir.exist?(File.join(root, "frontend"))
    end
  end

  def test_artifact_name_matches_the_release_web_client
    assert_equal "ruflet_client-web.tar.gz", Ruflet::Rails::WebInstaller::ASSET_NAME
    assert_equal "frontend", Ruflet::Rails::WebInstaller::TARGET_DIR
  end

  def test_failed_install_preserves_existing_frontend
    Dir.mktmpdir do |root|
      frontend = File.join(root, "frontend")
      FileUtils.mkdir_p(frontend)
      File.write(File.join(frontend, "index.html"), "working")

      with_stubs(
        release_asset_url: ->(*) { "https://example/broken.tar.gz" },
        download: ->(_url, path) { File.write(path, "not a tarball"); true }
      ) do
        refute Ruflet::Rails::WebInstaller.install!(root: root)
      end

      assert_equal "working", File.read(File.join(frontend, "index.html"))
    end
  end

  def test_force_false_preserves_existing_frontend
    Dir.mktmpdir do |root|
      frontend = File.join(root, "frontend")
      FileUtils.mkdir_p(frontend)
      File.write(File.join(frontend, "index.html"), "working")
      tarball = build_fake_web_tarball(root)

      with_stubs(
        release_asset_url: ->(*) { "https://example/ruflet_client-web.tar.gz" },
        download: ->(_url, path) { FileUtils.cp(tarball, path); true }
      ) do
        refute Ruflet::Rails::WebInstaller.install!(root: root, force: false)
      end

      assert_equal "working", File.read(File.join(frontend, "index.html"))
    end
  end

  private

  # Temporarily replace WebInstaller singleton methods (no minitest/mock dep).
  def with_stubs(stubs)
    mod = Ruflet::Rails::WebInstaller
    originals = stubs.keys.to_h { |name| [name, mod.method(name)] }
    stubs.each { |name, impl| mod.define_singleton_method(name, &impl) }
    yield
  ensure
    originals&.each { |name, m| mod.define_singleton_method(name, m) }
  end

  def build_fake_web_tarball(root)
    src = File.join(root, "src")
    FileUtils.mkdir_p(src)
    File.write(File.join(src, "index.html"), "<html><head></head><body>ok</body></html>")
    File.write(File.join(src, "main.dart.js"), "// js")
    tarball = File.join(root, "ruflet_client-web.tar.gz")
    system("tar", "-C", src, "-czf", tarball, ".") || raise("tar failed building fixture")
    tarball
  end
end
