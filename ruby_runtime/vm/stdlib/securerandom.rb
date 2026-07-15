# frozen_string_literal: true

# SecureRandom backed by the VM's random source. mruby-random is not a CSPRNG;
# in the embedded app context these values are used for session and widget
# identifiers, not cryptographic keys.
module SecureRandom
  class << self
    def random_bytes(length = 16)
      bytes = +""
      length.to_i.times { bytes << rand(256).chr }
      bytes
    end

    def hex(length = 16)
      random_bytes(length).bytes.map { |byte| format("%02x", byte) }.join
    end

    def uuid
      bytes = random_bytes(16).bytes
      bytes[6] = (bytes[6] & 0x0f) | 0x40
      bytes[8] = (bytes[8] & 0x3f) | 0x80
      hexed = bytes.map { |byte| format("%02x", byte) }.join
      [hexed[0, 8], hexed[8, 4], hexed[12, 4], hexed[16, 4], hexed[20, 12]].join("-")
    end

    def alphanumeric(length = 16)
      chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
      Array.new(length.to_i) { chars[rand(chars.length)] }.join
    end
  end
end
