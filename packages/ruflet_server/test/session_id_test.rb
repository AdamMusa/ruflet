# frozen_string_literal: true

require_relative "test_helper"

# ruflet_rails resumes the Page of whichever client presents a session id,
# so ids are bearer secrets. They used to be one rand(0..0xffff_ffff) draw
# followed by the server's CLOCK_REALTIME nanoseconds (AdamMusa/ruflet#114).
class RufletSessionIdTest < Minitest::Test
  UUID_V4 = /\A\h{8}-\h{4}-4\h{3}-[89ab]\h{3}-\h{12}\z/

  class ProtocolHost
    include Ruflet::ConnectionProtocol
  end

  def generators
    protocol = ProtocolHost.new
    server = Ruflet::Server.new(port: 0) { |_page| nil }
    {
      "Ruflet::SessionId.generate" => -> { Ruflet::SessionId.generate },
      "ConnectionProtocol#pseudo_uuid" => -> { protocol.send(:pseudo_uuid) },
      "Server#pseudo_uuid" => -> { server.send(:pseudo_uuid) }
    }
  end

  def test_ids_are_random_v4_uuids_in_the_shape_clients_store
    generators.each do |name, generate|
      ids = Array.new(32) { generate.call }

      ids.each { |id| assert_match UUID_V4, id, "#{name} returned #{id.inspect}" }
      assert_equal ids.size, ids.uniq.size, "#{name} repeated an id"
    end
  end

  # The old id's last four groups were the clock: decoding them landed inside
  # the window measured around the call.
  def test_ids_do_not_carry_the_server_clock
    generators.each do |name, generate|
      before = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
      id = generate.call
      after = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
      parts = id.split("-")
      decoded = parts[1].to_i(16) | (parts[2].to_i(16) << 16) | (parts[3].to_i(16) << 32) | (parts[4].to_i(16) << 48)

      refute_includes before..after, decoded, "#{name} encodes the clock: #{id}"
    end
  end

  def test_ids_come_from_securerandom
    calls = 0
    original = SecureRandom.method(:uuid)
    SecureRandom.singleton_class.send(:define_method, :uuid) do
      calls += 1
      original.call
    end

    generators.each_value(&:call)

    assert_equal 3, calls
  ensure
    SecureRandom.singleton_class.send(:define_method, :uuid, original) if original
  end

  def test_the_fallback_keeps_the_same_shape
    id = Ruflet::SessionId.fallback

    assert_match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/, id)
  end
end
