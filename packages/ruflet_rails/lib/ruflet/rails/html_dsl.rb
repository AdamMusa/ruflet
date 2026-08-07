# frozen_string_literal: true

require_relative "html_dsl/parser"
require_relative "html_dsl/styles"
require_relative "html_dsl/transformer"
require_relative "html_dsl/rack_fetcher"
require_relative "html_dsl/control_diff"
require_relative "html_dsl/html_app"
require_relative "html_dsl/view_helpers"

module Ruflet
  module Rails
    # HTML as the UI DSL: Rails views describe screens with markup
    # (`<column>`, `<row>`, `<text>`, `<button on-click>`, Tailwind-flavored
    # classes) and Ruflet renders them as real native controls — no WebView.
    module HtmlDsl
    end

    module_function

    # Render your Rails ERB views as native controls, over the WebSocket. Each
    # screen is a normal Rails route: it runs through routing and its controller
    # — params, before_actions, saving a form, loading records, assigning
    # `@ivars` — then the ERB view is compiled into a native control tree. The
    # dispatch is in-process (a function call, not network HTTP: no socket, no
    # disconnect); links navigate by URL and forms POST back through the
    # controller.
    #
    #   # app/views/ruflet/main.rb  (runs in the /ws session)
    #   Ruflet.run { |page| Ruflet::Rails.erb_to_native(page, start_url: "#{Ruflet::Rails.backend_url}/native") }
    #
    # A `fetcher:` can be injected for tests; production uses the in-process
    # RackFetcher by default.
    def erb_to_native(page, **opts)
      HtmlDsl::HtmlApp.new(page, **opts).start
    end
  end
end
