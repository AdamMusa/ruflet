# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "sync_apple_engine"

class RufletAppleEngineSyncTest < Minitest::Test
  def test_selected_sync_copies_only_requested_renderer_files
    with_renderer_roots do |source, target|
      write(source, "Sources/RufletEngine/Transport/New.swift", "new")
      write(source, "Sources/RufletEngine/Controls/Button.swift", "source-button")
      write(target, "Sources/RufletEngine/Controls/Button.swift", "target-button")

      status = RufletAppleEngineSync.run(
        ["--only", "Sources/RufletEngine/Transport/New.swift"],
        source: source,
        target: target
      )

      assert_equal 0, status
      assert_equal "new", File.read(File.join(target, "Sources/RufletEngine/Transport/New.swift"))
      assert_equal "target-button", File.read(File.join(target, "Sources/RufletEngine/Controls/Button.swift"))
    end
  end

  def test_full_sync_removes_stale_files_and_check_detects_drift
    with_renderer_roots do |source, target|
      write(source, "Sources/RufletEngine/Transport/Channel.swift", "source")
      write(target, "Sources/RufletEngine/Transport/Stale.swift", "stale")

      assert_equal 1, RufletAppleEngineSync.run(["--check"], source: source, target: target)
      assert_equal 0, RufletAppleEngineSync.run([], source: source, target: target)
      refute File.exist?(File.join(target, "Sources/RufletEngine/Transport/Stale.swift"))
      assert_equal 0, RufletAppleEngineSync.run(["--check"], source: source, target: target)
    end
  end

  private

  def with_renderer_roots
    Dir.mktmpdir do |directory|
      source = File.join(directory, "source")
      target = File.join(directory, "target")
      [source, target].each do |root|
        write(root, "Package.swift", "package")
        write(root, "Sources/RufletEngine/RufletApp.swift", "app")
      end
      yield source, target
    end
  end

  def write(root, relative, contents)
    path = File.join(root, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, contents)
  end
end
