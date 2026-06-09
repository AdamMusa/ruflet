# frozen_string_literal: true

module Ruflet
  module Rails
    module Protocol
      module WebSocketDetection
        def websocket_upgrade?(env)
          return false unless env["REQUEST_METHOD"] == "GET"

          upgrade    = env["HTTP_UPGRADE"].to_s.downcase
          connection = env["HTTP_CONNECTION"].to_s.downcase
          key        = env["HTTP_SEC_WEBSOCKET_KEY"].to_s

          upgrade == "websocket" && connection.include?("upgrade") && !key.empty?
        end
      end
    end
  end
end
