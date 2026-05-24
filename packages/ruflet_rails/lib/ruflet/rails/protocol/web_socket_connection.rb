# frozen_string_literal: true

require "ruflet_server"

module Ruflet
  module Rails
    module Protocol
      WebSocketConnection = ::Ruflet::WebSocketConnection unless const_defined?(:WebSocketConnection, false)
    end
  end
end
