# frozen_string_literal: true

require "minitest/autorun"

class AppleAutostartSourceTest < Minitest::Test
  SOURCE = File.read(File.expand_path("../apple/ruflet_runtime_autostart.h", __dir__))

  def test_packaged_runtime_selects_the_in_process_transport
    assert_includes SOURCE, '"RUFLET_RUNTIME_TRANSPORT"'
    assert_includes SOURCE, '"in_process"'
    assert_includes SOURCE, '@"inprocess://embedded"'
  end

  def test_packaged_runtime_does_not_publish_or_poll_a_loopback_port
    refute_includes SOURCE, '"RUFLET_RUNTIME_PORT_FILE"'
    refute_includes SOURCE, '@"server.port"'
    refute_includes SOURCE, '@"http://127.0.0.1:'
    refute_includes SOURCE, "usleep(1000)"
  end
end
