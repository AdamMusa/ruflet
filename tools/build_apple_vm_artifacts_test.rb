# frozen_string_literal: true

require "minitest/autorun"
require "open3"

class BuildAppleVmArtifactsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "tools/build_apple_vm_artifacts.sh")

  def test_script_is_valid_posix_shell
    _stdout, stderr, status = Open3.capture3("sh", "-n", SCRIPT)

    assert status.success?, stderr
  end

  def test_packaging_includes_host_and_in_process_bridge
    source = File.read(SCRIPT)

    assert_includes source, "ruflet_vm_host.cpp"
    assert_includes source, "ruflet_in_process_bridge.cpp"
    assert_includes source, '"$WORK/$prefix-host.o" "$WORK/$prefix-bridge.o"'
  end

  def test_build_does_not_replace_packaged_artifacts_without_install
    source = File.read(SCRIPT)

    assert_includes source, 'INSTALL=0'
    assert_includes source, 'if [ "$INSTALL" -eq 1 ]'
    assert_includes source, 'OUTPUT="$ROOT/build/vm/artifacts"'
  end
end
