# frozen_string_literal: true

require "ruflet/server"

module Ruflet
  module Rails
    module Protocol
      class LocalServer < ::Ruflet::Server
        def initialize(session_registry: Ruflet::Rails.sessions, view_root: nil, &app_block)
          @rails_app_block = app_block
          @session_registry = session_registry
          @view_root = view_root

          super(host: "0.0.0.0", port: 0) do |page|
            @session_registry.add(
              key: page.session_id,
              page: page,
              env: Context.current_env
            )
            Ruflet::Rails.load_views(@view_root) if @view_root
            @rails_app_block.call(page)
          end
        end

        private

        def remove_session(ws)
          page = @sessions_mutex.synchronize { @sessions[ws.session_key] } if ws
          @session_registry.remove(page.session_id) if page

          super
        end
      end
    end
  end
end
