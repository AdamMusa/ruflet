# frozen_string_literal: true

require "ruflet_server"

module Ruflet
  module Rails
    module Protocol
      WireCodec = ::Ruflet::WireCodec unless const_defined?(:WireCodec, false)
    end
  end
end
