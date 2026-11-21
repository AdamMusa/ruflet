# frozen_string_literal: true

require "json"
require "uri"

module Ruflet
  module Rails
    # Managed native shell for a Rails WebView body.
    class NativeApp
      Screen = Struct.new(:url, :view, :webview, :loading, :body, :title_text, :appbar_spec, :appbar_signature,
                          :drawer, :end_drawer, :drawer_signature, :rail, :rail_signature, keyword_init: true)

      def initialize(page, start_url:, title: nil, actions: nil, navigation_bar: nil, bottom_appbar: nil,
                     loading: :shimmer, trusted_origins: nil)
        @page = page
        @start_url = start_url.to_s
        configure_trusted_origins(@start_url, trusted_origins)
        @main_frame = new_bridge_frame(@start_url)
        @title = title.to_s
        @actions = actions
        @navigation_bar = navigation_bar
        @bottom_appbar = bottom_appbar
        @loading = loading
        @screens = []
        @sheet = nil
        @dialog = nil
        @bottomnav_signature = nil
        @bottomnav_spec = nil
        @appbar_specs_by_url = {}
        @drawer_spec = nil
        @drawer_open_requested = false
      end

      def start
        @page.on_view_pop = ->(_event) { pop }
        push_webview(@start_url, root: true)
        self
      end
    end
  end
end

require_relative "native_app/html_adapter"
require_relative "native_app/origin_trust"
require_relative "native_app/customization"
require_relative "native_app/shell"
require_relative "native_app/navigation"
require_relative "native_app/actions"
require_relative "native_app/overlays"

module Ruflet
  module Rails
    module_function

    # Wrap your Rails web pages in a native shell: the body stays a WebView
    # while Ruflet owns the native chrome (app bar, drawer, navigation, sheets,
    # dialogs, services). See NativeApp. Only pages on start_url's origin (or
    # one listed in `trusted_origins:`) may drive the shell; see
    # NativeApp::BridgeFrame.
    def native_shell(page, **opts)
      NativeApp.new(page, **opts).start
    end
  end
end
