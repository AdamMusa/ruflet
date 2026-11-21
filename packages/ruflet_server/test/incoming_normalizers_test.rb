# frozen_string_literal: true

require_relative "test_helper"

# normalize_incoming and normalize_event_data (Ruflet::Server and
# Ruflet::ConnectionProtocol) loop with while so that each level of nesting
# costs one call: the embedded mruby VM allows 512 nested calls, and the
# block forms overflowed below WireCodec::MAX_NESTING_DEPTH. Their results
# must be exactly what the block forms returned.
class RufletIncomingNormalizersTest < Minitest::Test
  class ProtocolHost
    include Ruflet::ConnectionProtocol
  end

  # The block forms, as they were.
  module Reference
    module_function

    def normalize_incoming(value)
      case value
      when String
        value.dup.force_encoding("UTF-8")
      when Integer, Float, TrueClass, FalseClass, NilClass
        value
      when Symbol
        value.to_s
      when Array
        value.map { |v| normalize_incoming(v) }
      when Hash
        value.each_with_object({}) do |(k, v), out|
          out[k.to_s] = normalize_incoming(v)
        end
      else
        value.to_s
      end
    end

    def normalize_event_data(value)
      case value
      when Hash
        value.each_with_object({}) { |(k, v), out| out[k.to_sym] = normalize_event_data(v) }
      when Array
        value.map { |entry| normalize_event_data(entry) }
      else
        value
      end
    end
  end

  Opaque = Struct.new(:label) do
    def to_s = "opaque:#{label}"
  end

  def receivers
    [Ruflet::Server.new(host: "127.0.0.1", port: 0) { |_page| nil }, ProtocolHost.new]
  end

  def test_the_results_match_the_block_forms_for_random_values
    random = Random.new(20_261_121)
    values = Array.new(1500) { random_value(random, 0) }

    receivers.each do |receiver|
      values.each_with_index do |value, index|
        %i[normalize_incoming normalize_event_data].each do |name|
          expected = outcome { Reference.public_send(name, value) }
          actual = outcome { receiver.send(name, value) }

          assert_equal expected, actual, "#{receiver.class} #{name} value #{index}: #{value.inspect}"
        end
        incoming = receiver.send(:normalize_incoming, value)
        assert_equal outcome { Reference.normalize_event_data(Reference.normalize_incoming(value)) },
                     outcome { receiver.send(:normalize_event_data, incoming) },
                     "#{receiver.class} event data of value #{index}"
      end
    end
  end

  # One call per level: in a CRuby connection thread the block forms
  # overflowed at about 350 levels of maps.
  def test_deep_values_are_normalized_without_exhausting_the_stack
    maps = nil
    2_000.times { maps = { "k" => maps } }
    arrays = nil
    2_000.times { arrays = [arrays] }

    receivers.each do |receiver|
      Thread.new do
        [maps, arrays].each do |value|
          receiver.send(:normalize_event_data, receiver.send(:normalize_incoming, value))
        end
      end.join
    end
  end

  private

  # The value's exact bytes (Marshal keeps classes, encodings, key order
  # and NaN), or the error it raised.
  def outcome
    Marshal.dump(yield)
  rescue StandardError => e
    [e.class, e.message]
  end

  # Top-level values are arrays or maps; deeper ones are anything.
  def random_value(random, depth)
    kind = if depth.zero?
             9 + random.rand(2)
           else
             random.rand(depth > 4 ? 9 : 11)
           end
    case kind
    when 0 then random_string(random)
    when 1 then random.rand(-2**70..2**70)
    when 2 then random.rand(-300..300)
    when 3 then [random.rand * 1e6, -0.0, Float::INFINITY, Float::NAN][random.rand(4)]
    when 4 then [true, false, nil][random.rand(3)]
    when 5 then :"sym_#{random.rand(5)}"
    when 6 then Opaque.new(random.rand(3))
    when 7 then random_string(random).b
    when 8 then nil
    when 9 then Array.new(random.rand(6)) { random_value(random, depth + 1) }
    else
      Array.new(random.rand(6)).each_with_object({}) do |_, out|
        out[random_key(random)] = random_value(random, depth + 1)
      end
    end
  end

  # Keys a decoded map never has (symbols, integers, nil) included, and
  # keys that collide once stringified, so the iteration order shows.
  def random_key(random)
    case random.rand(6)
    when 0, 1 then %w[a b c 1 data][random.rand(5)]
    when 2 then random.rand(3)
    when 3 then %i[a b][random.rand(2)]
    when 4 then nil
    else random_string(random)
    end
  end

  def random_string(random)
    pool = ["", "a", "é", "日本", "\xff\xfe".b, "x" * 40]
    pool[random.rand(pool.size)].dup
  end
end
