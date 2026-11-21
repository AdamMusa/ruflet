# frozen_string_literal: true

require "digest"

# Stand-in for the rqrcode gem (a runtime dependency of the ruflet gem) so the
# `ruflet run` QR banner renders the same on every machine regardless of
# which rqrcode version is installed. The CLI's own half-block rendering of
# the module matrix is what the goldens exercise; the matrix here is a fixed
# function of the payload.
module RQRCode
  class QRCode
    SIZE = 9

    attr_reader :modules

    def initialize(payload)
      bits = Digest::SHA256.digest(payload.to_s).unpack1("B*")
      @modules = Array.new(SIZE) { |y| Array.new(SIZE) { |x| bits[(y * SIZE) + x] == "1" } }
    end
  end
end
