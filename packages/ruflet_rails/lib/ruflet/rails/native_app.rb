# frozen_string_literal: true

require "uri"

module Ruflet
  module Rails
    # Managed webview navigation driver for ruflet_rails.
    #
    # Your existing web app is the body, rendered in a WebView. Navigation works
    # out of the box: a tiny JS bridge injected into each page intercepts link
    # clicks and proposes them to native, so every visit becomes a NATIVE screen
    # pushed onto the stack (with an automatic back button) — no per-link code.
    # The native AppBar title tracks each page's <title>, and you declare special
    # paths as data.
    #
    #   Ruflet.run do |page|
    #     Ruflet::Rails.native_app(
    #       page,
    #       start_url: "https://myapp.com",
    #       title: "My App",                              # auto-updates from <title>
    #       actions: -> { [icon_button("search", on_click: ->(_e) { ... })] },
    #       navigation_bar: navigation_bar(destinations: [...]),
    #
    #       # web content shown in a bottom sheet (auth, quick forms):
    #       modal: ["/sign_in", "/sign_up", %r{/new\z}],
    #
    #       # optional: override a path with a fully native screen:
    #       native: { %r{\A/products/(\d+)\z} => ->(ctx) { product_screen(ctx.match[1]) } }
    #     )
    #   end
    #
    # Normal links just push a native webview screen (back returns). Paths listed
    # in `modal:` open as a bottom sheet. Paths in `native:` render your own UI.
    #
    # The bridge talks to native over the webview's console channel
    # (on_console_message), which works on iOS/Android/macOS. On platforms
    # without a native webview the body degrades to a plain frame.
    class NativeApp
      # Injected into every page: report the title, and turn same-origin link
      # clicks into native visit proposals (so they don't load in place).
      BRIDGE_JS = <<~JS
        (function () {
          function report(kind, value) { console.log("ruflet:" + kind + ":" + value); }
          report("title", document.title || "");
          if (window.__rufletBridgeBound) return;
          window.__rufletBridgeBound = true;
          document.addEventListener("click", function (e) {
            var a = e.target && e.target.closest ? e.target.closest("a[href]") : null;
            if (!a || a.target === "_blank") return;
            if (a.origin && a.origin !== location.origin) return; // external: leave it
            e.preventDefault();
            report("visit", a.href);
          }, true);
        })();
      JS

      VISIT_PREFIX = "ruflet:visit:"
      TITLE_PREFIX = "ruflet:title:"

      Screen  = Struct.new(:kind, :url, :view, :webview, :title_text, keyword_init: true)
      Context = Struct.new(:url, :path, :match, keyword_init: true)

      def initialize(page, start_url:, title: nil, actions: nil, navigation_bar: nil,
                     bottom_appbar: nil, modal: [], native: {})
        @page = page
        @start_url = start_url.to_s
        @title = title.to_s
        @actions = actions
        @navigation_bar = navigation_bar
        @bottom_appbar = bottom_appbar
        @modal_patterns = Array(modal).map { |p| compile_pattern(p) }
        @native_rules = native.map { |pattern, builder| [compile_pattern(pattern), builder] }
        @screens = []
        @modal_sheet = nil
      end

      def self.bridge_js = BRIDGE_JS

      def start
        @page.on_view_pop = ->(_event) { pop }
        push_webview(@start_url, root: true)
        self
      end

      private

      # --- Stack operations ---------------------------------------------------

      def push_webview(url, root: false)
        screen = Screen.new(kind: :webview, url: url.to_s)
        screen.title_text = Ruflet::UI::ControlFactory.build(:text, value: @title)
        screen.webview = build_webview(screen)
        screen.view = build_view(screen, root: root)
        @screens.push(screen)
        flush
        screen
      end

      def push_native(builder, ctx)
        view = builder.call(ctx)
        return unless view.is_a?(Ruflet::Control)

        @screens.push(Screen.new(kind: :native, url: ctx.url, view: view))
        flush
      end

      def pop
        return if @screens.size <= 1

        @screens.pop
        flush
      end

      def flush
        @page.views = @screens.map(&:view)
        @page.update
      end

      # --- Webview screen + native chrome ------------------------------------

      def build_webview(screen)
        Ruflet::UI::ControlFactory.build(
          :webview,
          url: screen.url,
          method: "get",
          expand: true,
          on_page_ended: ->(_event) { inject_bridge(screen) },
          on_console_message: ->(event) { handle_message(screen, message_of(event)) }
        )
      end

      def build_view(screen, root:)
        args = { route: root ? "/" : "/screen", controls: [screen.webview], appbar: build_appbar(screen) }
        if root
          args[:navigation_bar] = @navigation_bar unless @navigation_bar.nil?
          args[:bottom_appbar] = @bottom_appbar unless @bottom_appbar.nil?
        end
        Ruflet::UI::ControlFactory.build(:view, **args)
      end

      def build_appbar(screen)
        args = { title: screen.title_text }
        actions = resolve_actions
        args[:actions] = actions if actions
        Ruflet::UI::ControlFactory.build(:appbar, **args)
      end

      def resolve_actions
        @actions.respond_to?(:call) ? @actions.call : @actions
      end

      # --- Bridge ------------------------------------------------------------

      def inject_bridge(screen)
        screen.webview.run_javascript(BRIDGE_JS) if screen.webview.respond_to?(:run_javascript)
      rescue StandardError
        nil
      end

      def handle_message(screen, message)
        return if message.nil?

        if message.start_with?(TITLE_PREFIX)
          update_title(screen, message[TITLE_PREFIX.length..])
        elsif message.start_with?(VISIT_PREFIX)
          visit(message[VISIT_PREFIX.length..])
        end
      end

      def update_title(screen, value)
        return unless screen.title_text&.wire_id

        @page.update(screen.title_text, value: value.to_s)
      end

      # A proposed visit: native screen > modal sheet > push a webview screen.
      def visit(url)
        path = path_of(url)
        return if path.nil?

        builder, match = match_native(path)
        if builder
          push_native(builder, Context.new(url: url, path: path, match: match))
        elsif modal?(path)
          present_modal(url)
        else
          push_webview(url)
        end
      end

      # --- Modal (bottom sheet of web content) -------------------------------

      def present_modal(url)
        sheet_webview = Ruflet::UI::ControlFactory.build(:webview, url: url.to_s, method: "get", expand: true)
        @modal_sheet = Ruflet::UI::ControlFactory.build(
          :bottomsheet,
          open: true,
          dismissible: true,
          content: Ruflet::UI::ControlFactory.build(:container, height: 520, content: sheet_webview),
          on_dismiss: ->(_event) { @modal_sheet = nil }
        )
        @page.bottom_sheet = @modal_sheet
        @page.update
      end

      # --- Matching ----------------------------------------------------------

      def match_native(path)
        @native_rules.each do |pattern, builder|
          if pattern.is_a?(Regexp)
            m = pattern.match(path)
            return [builder, m] if m
          elsif pattern == path
            return [builder, nil]
          end
        end
        nil
      end

      def modal?(path)
        @modal_patterns.any? do |pattern|
          pattern.is_a?(Regexp) ? pattern.match?(path) : pattern == path
        end
      end

      def compile_pattern(pattern)
        return pattern if pattern.is_a?(Regexp)

        value = pattern.to_s
        value.start_with?("/") ? value : "/#{value}"
      end

      def path_of(url)
        URI.parse(url.to_s).path
      rescue URI::InvalidURIError
        nil
      end

      def message_of(event)
        data = event.respond_to?(:data) ? event.data : event
        return data["message"] || data[:message] if data.is_a?(Hash)

        data
      end
    end

    module_function

    # Start a managed webview app. See NativeApp.
    def native_app(page, **opts)
      NativeApp.new(page, **opts).start
    end
  end
end
