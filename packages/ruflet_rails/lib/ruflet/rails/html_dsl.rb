# frozen_string_literal: true

require_relative "html_dsl/parser"
require_relative "html_dsl/styles"
require_relative "html_dsl/transformer"
require_relative "html_dsl/template_source"
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
    # screen is a controller action, found by convention from its path (see
    # NativeScreens): the action runs — params, saving a form, loading
    # records, assigning `@ivars` — then the ERB view is compiled into a
    # native control tree. The dispatch is in-process, a direct method call
    # inside the session (see TemplateSource): there is no request, so
    # routing, middleware and the controller's callbacks (before_action and
    # friends) do not run, and a leading HTTP verb on an action URL is
    # ignored. Links navigate by URL and forms hand their fields to the action
    # their `action` names.
    #
    #   # app/views/ruflet/main.rb  (runs in the /ws session)
    #   Ruflet.run { |page| Ruflet::Rails.erb_to_native(page, start_url: "/native") }
    #
    # `start_url` is a path, because there is no second connection to point at:
    # the client dials one route (the WebSocket) and every screen after that is
    # dispatched in-process. A full URL is still accepted; only its path picks
    # the screen. Media URLs, the one thing the client fetches for itself, take
    # their host from `config.backend_url` or, without one, from the
    # connection the client actually made, so a phone on the LAN and a browser
    # on localhost both work without configuring anything.
    #
    # A `fetcher:` can be injected for tests.
    def erb_to_native(page, start_url: "/", **opts)
      opts[:fetcher] ||= HtmlDsl::TemplateSource.new
      HtmlDsl::HtmlApp.new(page, start_url: start_url, **opts).start
    end
  end
end
