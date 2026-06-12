# frozen_string_literal: true

require "uri"

module Ruflet
  module Rails
    # Hotwire Native-style driver for ruflet_rails.
    #
    # The body is your existing web app rendered in a WebView. You declare a
    # PATH CONFIGURATION mapping URL patterns to native screens — and that's it.
    # Navigation follows the web app; when the user reaches a path you've
    # promoted, the native screen is pushed automatically. No imperative
    # `if route == ...` branching.
    #
    #   Ruflet.run do |page|
    #     Ruflet::Rails.native_app(
    #       page,
    #       start_url: "https://myapp.com",
    #       appbar: app_bar(title: text("My App")),
    #       navigation_bar: navigation_bar(destinations: [...]),
    #       paths: {
    #         %r{\A/products/(\d+)\z} => ->(ctx) { product_screen(ctx.match[1]) },
    #         "/cart"                 => ->(ctx) { cart_screen },
    #       }
    #     )
    #   end
    #
    # Anything not matched stays in the webview (ordinary web browsing). A matched
    # path renders its native screen, pushed on top with an automatic back button;
    # popping returns to the webview, which persists underneath. Each path builder
    # receives a Context (url, path, regexp match) and returns a native View.
    class NativeApp
      Context = Struct.new(:url, :path, :match, keyword_init: true)

      def initialize(page, start_url:, appbar: nil, navigation_bar: nil,
                     bottom_appbar: nil, prevent_links: nil, paths: {})
        @page = page
        @start_url = start_url.to_s
        @appbar = appbar
        @navigation_bar = navigation_bar
        @bottom_appbar = bottom_appbar
        @prevent_links = prevent_links
        @rules = normalize_paths(paths)
        @stack = []
      end

      def start
        @page.on_view_pop = ->(_event) { pop }
        @stack = [base_screen]
        flush
        self
      end

      private

      # The persistent web body — built once and reused across native pushes.
      def base_screen
        @base_screen ||= Ruflet::Rails.webview_app(
          url: @start_url,
          appbar: @appbar,
          navigation_bar: @navigation_bar,
          bottom_appbar: @bottom_appbar,
          prevent_links: @prevent_links,
          route: "/",
          on_navigate: ->(url) { promote(url) }
        )
      end

      # A web navigation arrived — promote it to a native screen if a path rule
      # matches; otherwise leave it to the webview.
      def promote(url)
        path = path_of(url)
        return if path.nil?

        builder, match = match_rule(path)
        return unless builder

        screen = builder.call(Context.new(url: url, path: path, match: match))
        return unless screen.is_a?(Ruflet::Control)

        @stack.push(screen)
        flush
      end

      def pop
        return if @stack.size <= 1

        @stack.pop
        flush
      end

      def flush
        @page.views = @stack
        @page.update
      end

      def match_rule(path)
        @rules.each do |matcher, builder|
          if matcher.is_a?(Regexp)
            m = matcher.match(path)
            return [builder, m] if m
          elsif matcher == path
            return [builder, nil]
          end
        end
        nil
      end

      def path_of(url)
        URI.parse(url.to_s).path
      rescue URI::InvalidURIError
        nil
      end

      def normalize_paths(paths)
        paths.map do |matcher, builder|
          key = matcher.is_a?(Regexp) ? matcher : normalize_path_string(matcher)
          [key, builder]
        end
      end

      def normalize_path_string(value)
        value = value.to_s
        value.start_with?("/") ? value : "/#{value}"
      end
    end

    module_function

    # Start a Hotwire Native-style app. See NativeApp.
    def native_app(page, **opts)
      NativeApp.new(page, **opts).start
    end
  end
end
