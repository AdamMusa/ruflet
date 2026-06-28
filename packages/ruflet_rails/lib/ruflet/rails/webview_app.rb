# frozen_string_literal: true

module Ruflet
  module Rails
    # Build a "webview app" shell: a native screen whose body is a WebView, with
    # a native AppBar on top and a native NavigationBar (or bottom AppBar) below.
    # The chrome stays native while the body shows your website.
    #
    #   Ruflet.run do |page|
    #     page.views = [
    #       Ruflet::Rails.webview_app(
    #         url: "https://myapp.com",
    #         appbar: app_bar(title: text("My App")),
    #         navigation_bar: navigation_bar(destinations: [...]),
    #         on_navigate: ->(url) { page.go("/details") if url.include?("/product/") }
    #       )
    #     ]
    #   end
    #
    # on_navigate fires from the webview's url change as the user navigates, with
    # the target URL — map it to a native route with page.go. (prevent_links can
    # additionally stop the webview from ever loading matching URLs.) Pass a block
    # to capture the WebView control itself (e.g. to run_javascript on it later).
    module_function

    def webview_app(url:, appbar: nil, navigation_bar: nil, bottom_appbar: nil,
                    route: "/", prevent_links: nil, on_navigate: nil,
                    on_page_started: nil, on_page_ended: nil, **webview_props)
      webview_args = { url: url, method: "get", expand: true }
      webview_args[:prevent_links] = prevent_links unless prevent_links.nil?
      webview_args[:on_url_change] = ->(event) { on_navigate.call(event.data) } if on_navigate
      webview_args[:on_page_started] = on_page_started if on_page_started
      webview_args[:on_page_ended] = on_page_ended if on_page_ended
      webview_args.merge!(webview_props)

      body = Ruflet::UI::ControlFactory.build(:webview, **webview_args)
      yield body if block_given?

      view_args = { route: route, controls: [body] }
      view_args[:appbar] = appbar unless appbar.nil?
      view_args[:navigation_bar] = navigation_bar unless navigation_bar.nil?
      view_args[:bottom_appbar] = bottom_appbar unless bottom_appbar.nil?

      Ruflet::UI::ControlFactory.build(:view, **view_args)
    end
  end
end
