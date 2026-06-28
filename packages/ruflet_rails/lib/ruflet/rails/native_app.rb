# frozen_string_literal: true

require "json"
require "uri"

module Ruflet
  module Rails
    # Managed webview driver for ruflet_rails.
    #
    # Your existing web app is the body, rendered in a WebView. A tiny JS bridge
    # injected into each page reports the title and turns explicitly annotated
    # elements into native screens, dialogs, toasts, tabs, or app bars. Plain
    # links and Turbo visits stay inside the WebView. Native chrome is opt-in:
    # pass a `title:` or
    # `actions:` to get an AppBar (whose title tracks each page's <title>); with
    # neither, screens are full-bleed webviews so the page's own header isn't
    # duplicated.
    #
    #   Ruflet.run do |page|
    #     Ruflet::Rails.native_app(
    #       page,
    #       start_url: "https://myapp.com",
    #       title: "My App",                              # auto-updates from <title>
    #       actions: -> { [icon_button("search", on_click: ->(_e) { ... })] },
    #       navigation_bar: navigation_bar(destinations: [...])
    #     )
    #   end
    #
    # Native behavior is DECLARED in the page, not guessed by the framework.
    # There is no implicit same-origin link interception. A developer annotates
    # elements with Ruflet-owned `data-ruflet-*` attributes, or explicitly lists
    # external links in `screen_links:` when the HTML lives outside the Rails
    # app, and the bridge turns those declarations into native actions:
    #
    #   * `data-ruflet-screen='{"action":"push|replace|root|sheet|back"}'`
    #     plus `href` / `url` — screen navigation or bottom-sheet web content.
    #   * `data-ruflet-action='{"component":"dialog",...}'` — AlertDialog.
    #   * `data-ruflet-action='{"component":"toast",...}'` — SnackBar.
    #   * `data-ruflet-appbar` / `data-ruflet-tabs` / `data-ruflet-drawer` / `data-ruflet-rail`
    #     (scanned on load) — hide the HTML header / nav and render native
    #     AppBar / NavigationBar / NavigationDrawer / NavigationRail.
    #
    # App JS can trigger the same actions via the injected `RufletNative` object
    # (`RufletNative.navigate("/x", "push")`, `.dialog({...})`, `.sheet("/x")`,
    # `.toast("Saved")`, `.back()`). In ERB, keep using normal Rails helpers
    # like `link_to` and add `data-ruflet-*` where native behavior should
    # augment the web page. The page still renders normally in a plain browser.
    #
    # The bridge talks to native over the webview's console channel
    # (on_console_message), which works on iOS/Android/macOS. On platforms
    # without a native webview the body degrades to a plain frame.
    class NativeApp
      # Injected into every page. It reports the title, packs any
      # `data-ruflet-*` params into JSON on click, and on load promotes
      # annotated `data-ruflet-appbar` / `data-ruflet-tabs` /
      # `data-ruflet-drawer` / `data-ruflet-rail` chrome to native controls.
      BRIDGE_JS = <<~JS
        (function () {
          var configuredScreenLinks = __RUFLET_SCREEN_LINKS__;
          function report(kind, value) { console.log("ruflet:" + kind + ":" + value); }
          function attr(el, name) {
            var v = el.getAttribute(name);
            if (v != null) return v;
            v = el.getAttribute("data-" + name);
            if (v != null) return v;
            return el.getAttribute("data-ruflet-" + name);
          }
          function has(el, name) {
            return el.hasAttribute(name) || el.hasAttribute("data-" + name) || el.hasAttribute("data-ruflet-" + name);
          }
          function readJSON(raw) {
            if (!raw) return {};
            try { return JSON.parse(raw); } catch (_) { return {}; }
          }
          function configuredScreenFor(a) {
            if (!a || !a.href) return null;
            var url;
            try { url = new URL(a.href, location.href); } catch (_) { return null; }
            for (var i = 0; i < configuredScreenLinks.length; i++) {
              var rule = configuredScreenLinks[i] || {};
              if (rule.href && url.href !== rule.href) continue;
              if (rule.host && url.host !== rule.host) continue;
              if (rule.path && url.pathname !== rule.path) continue;
              var payload = Object.assign({ component: "navigation", action: "push" }, rule.payload || {}, rule);
              delete payload.href;
              delete payload.host;
              delete payload.path;
              delete payload.payload;
              payload.url = payload.url || url.href;
              return payload;
            }
            return null;
          }

          // Programmatic API for app code.
          window.RufletNative = window.RufletNative || {
            navigate: function (url, action) { report("action", JSON.stringify({ component: "navigation", url: url || "", action: action || "push" })); },
            dialog: function (spec) { report("action", JSON.stringify(Object.assign({ component: "dialog" }, spec || {}))); },
            sheet: function (url) { report("action", JSON.stringify({ component: "navigation", action: "sheet", url: url || "" })); },
            toast: function (message, opts) { report("action", JSON.stringify(Object.assign({ component: "toast", message: message }, opts || {}))); },
            back: function () { report("action", JSON.stringify({ component: "navigation", action: "back" })); }
          };

          // Promote annotated HTML chrome to native controls. Runs on every
          // injection (each page load) so it re-syncs after navigation.
          function syncChrome() {
            var promotedAppBar = false;
            var bar = document.querySelector("[ruflet-appbar],[data-ruflet-appbar]");
            if (bar) {
              promotedAppBar = true;
              bar.style.display = "none";
              var appbar = readJSON(attr(bar, "ruflet-appbar"));
              var heading = bar.querySelector("h1,h2,.title");
              var title = appbar.title || attr(bar, "ruflet-title") || (heading ? heading.textContent : "") || document.title || "";
              var leading = appbar.leading || null;
              var leadingEl = bar.querySelector("[ruflet-leading],[data-ruflet-leading]");
              if (leadingEl) leading = readJSON(attr(leadingEl, "ruflet-leading"));
              var actions = [];
              bar.querySelectorAll("[ruflet-icon],[data-ruflet-icon]").forEach(function (el) {
                var icon = readJSON(attr(el, "ruflet-icon"));
                actions.push({
                  icon: icon.icon || attr(el, "ruflet-icon"),
                  url: el.getAttribute("href") || icon.url || attr(el, "ruflet-url") || "",
                  action: icon.action || attr(el, "ruflet-action") || "push"
                });
              });
              if (appbar.actions && appbar.actions.length) actions = appbar.actions.concat(actions);
              report("appbar", JSON.stringify({ title: (title || "").trim(), leading: leading, actions: actions }));
            }
            var nav = document.querySelector("[ruflet-tabs],[data-ruflet-tabs]");
            if (nav) {
              nav.style.display = "none";
              var items = [];
              nav.querySelectorAll("a[href]").forEach(function (a) {
                var icon = readJSON(attr(a, "ruflet-icon"));
                items.push({
                  label: icon.label || attr(a, "ruflet-label") || a.textContent.trim(),
                  icon: icon.icon || attr(a, "ruflet-icon") || "circle",
                  color: icon.color || "",
                  size: icon.size || "",
                  url: a.getAttribute("href"),
                  selected: has(a, "ruflet-selected")
                });
              });
              if (items.length >= 2) report("bottomnav", JSON.stringify({ items: items }));
            }
            var drawer = document.querySelector("[ruflet-drawer],[data-ruflet-drawer]");
            if (drawer) {
              drawer.style.display = "none";
              var drawerSpec = readJSON(attr(drawer, "ruflet-drawer"));
              var drawerItems = [];
              drawer.querySelectorAll("a[href]").forEach(function (a) {
                var icon = readJSON(attr(a, "ruflet-icon"));
                drawerItems.push({
                  label: icon.label || attr(a, "ruflet-label") || a.textContent.trim(),
                  icon: icon.icon || attr(a, "ruflet-icon") || "circle",
                  url: a.getAttribute("href"),
                  action: icon.action || attr(a, "ruflet-action") || drawerSpec.action || "root",
                  selected: has(a, "ruflet-selected")
                });
              });
              if (drawerItems.length) report("drawer", JSON.stringify(Object.assign({}, drawerSpec, { items: drawerItems })));
            }
              var rail = document.querySelector("[ruflet-rail],[data-ruflet-rail]");
            if (rail) {
              rail.style.display = "none";
              var railSpec = readJSON(attr(rail, "ruflet-rail"));
              if (railSpec.breakpoint && window.innerWidth < Number(railSpec.breakpoint)) return;
              var railItems = [];
              rail.querySelectorAll("a[href]").forEach(function (a) {
                var icon = readJSON(attr(a, "ruflet-icon"));
                railItems.push({
                  label: icon.label || attr(a, "ruflet-label") || a.textContent.trim(),
                  icon: icon.icon || attr(a, "ruflet-icon") || "circle",
                  url: a.getAttribute("href"),
                  action: icon.action || attr(a, "ruflet-action") || railSpec.action || "root",
                  selected: has(a, "ruflet-selected")
                });
              });
              if (railItems.length >= 2) report("rail", JSON.stringify(Object.assign({}, railSpec, { items: railItems })));
            }
            return promotedAppBar;
          }
          var promotedAppBar = syncChrome();
          if (!promotedAppBar) report("title", document.title || "");

          if (window.__rufletBridgeBound) return;
          window.__rufletBridgeBound = true;

          document.addEventListener("click", function (e) {
            var t = e.target;
            var nav = t && t.closest ? t.closest("[ruflet-screen],[data-ruflet-screen]") : null;
            if (nav) {
              e.preventDefault();
              var spec = readJSON(attr(nav, "ruflet-screen"));
              spec.component = spec.component || "navigation";
              spec.url = nav.getAttribute("href") || spec.url || attr(nav, "ruflet-url") || "";
              report("action", JSON.stringify(spec));
              return;
            }

            var el = t && t.closest ? t.closest("[ruflet-action],[data-ruflet-action]") : null;
            if (el) {
              e.preventDefault();
              var payload = readJSON(attr(el, "ruflet-action"));
              payload.url = el.getAttribute("href") || payload.url || attr(el, "ruflet-url") || "";
              report("action", JSON.stringify(payload));
              return;
            }

            var a = t && t.closest ? t.closest("a[href]") : null;
            var configured = configuredScreenFor(a);
            if (configured) {
              e.preventDefault();
              report("action", JSON.stringify(configured));
            }
          }, true);
        })();
      JS

      TITLE_PREFIX     = "ruflet:title:"
      ACTION_PREFIX    = "ruflet:action:"
      APPBAR_PREFIX    = "ruflet:appbar:"
      BOTTOMNAV_PREFIX = "ruflet:bottomnav:"
      DRAWER_PREFIX    = "ruflet:drawer:"
      RAIL_PREFIX      = "ruflet:rail:"

      Screen = Struct.new(:url, :view, :webview, :loading, :body, :title_text, :appbar_spec, :appbar_signature,
                          :drawer, :end_drawer, :drawer_signature, :rail, :rail_signature, :route, keyword_init: true)

      def initialize(page, start_url:, title: nil, actions: nil, navigation_bar: nil, bottom_appbar: nil,
                     screen_links: [], loading: :shimmer)
        @page = page
        @start_url = start_url.to_s
        @title = title.to_s
        @actions = actions
        @navigation_bar = navigation_bar
        @bottom_appbar = bottom_appbar
        @loading = loading
        @screen_links = normalize_screen_links(screen_links)
        @screens = []
        @sheet = nil
        @dialog = nil
        @screen_seq = 0
        @bottomnav_signature = nil
        @bottomnav_spec = nil
        @appbar_specs_by_url = {}
        @drawer_spec = nil
        @drawer_open_requested = false
      end

      def self.bridge_js(screen_links: [])
        BRIDGE_JS.sub("__RUFLET_SCREEN_LINKS__", JSON.generate(screen_links))
      end

      def start
        @page.on_view_pop = ->(_event) { pop }
        push_webview(@start_url, root: true)
        self
      end

      private

      # --- Stack operations ---------------------------------------------------

      def push_webview(url, root: false, spec: nil)
        url = absolute_url(url)
        return if url.empty?

        screen = Screen.new(url: url)
        # Each view's route is its Navigator page key on the client
        # (page.dart: ValueKey(view.route)). The root is "/"; every other screen
        # gets a unique route so stacking two webview screens (e.g. a redirect
        # hopping /landing -> /menu) never collides keys and trips Flutter's
        # `!keyReservation.contains(key)` assertion.
        screen.route = root ? "/" : "/screen/#{@screen_seq += 1}"
        screen.appbar_spec = appbar_spec_from(spec)
        screen.appbar_spec ||= default_screen_appbar_spec(url) unless root
        screen.title_text = Ruflet::UI::ControlFactory.build(:text, value: title_for(screen))
        screen.loading = build_loading_state
        screen.webview = build_webview(screen)
        screen.body = build_webview_body(screen)
        screen.view = build_view(screen, root: root)
        @screens.push(screen)
        flush
        screen
      end

      def pop
        return if @screens.size <= 1

        @screens.pop
        flush
        close_drawer(@screens.last, retry_close: true)
        refresh_root_drawer
        sync_drawer_selection(@screens.last)
        refresh_root_navigation_bar
      end

      def flush
        @page.views = @screens.map(&:view)
        @page.update
        reconcile_loading_visibility
      end

      # --- Webview screen + native chrome ------------------------------------

      def build_webview(screen)
        Ruflet::UI::ControlFactory.build(
          :webview,
          url: screen.url,
          method: "get",
          expand: true,
          enable_javascript: true,
          # The mobile client defaults JavaScriptMode to disabled and ignores the
          # enable_javascript prop, so switch JS on as each page starts loading.
          # Without it the in-page bridge can't run (no link interception → no
          # screen navigation) and WebAuthn/passkeys won't work.
          on_page_started: lambda do |_event|
            show_loading(screen)
            enable_js(screen.webview)
          end,
          on_page_ended: lambda do |_event|
            inject_bridge(screen)
            hide_loading(screen)
          end,
          on_web_resource_error: ->(_event) { hide_loading(screen) },
          on_console_message: ->(event) { handle_message(screen, message_of(event)) }
        )
      end

      def build_webview_body(screen)
        return screen.webview unless screen.loading

        Ruflet::UI::ControlFactory.build(
          :stack,
          controls: [screen.webview, screen.loading],
          fit: "expand",
          expand: true
        )
      end

      def build_view(screen, root:)
        args = { route: screen.route || (root ? "/" : "/screen"), controls: screen_controls(screen) }
        appbar = build_appbar(screen)
        args[:appbar] = appbar if appbar
        args[:drawer] = screen.drawer if screen.drawer
        args[:end_drawer] = screen.end_drawer if screen.end_drawer
        if root
          args[:navigation_bar] = @navigation_bar unless @navigation_bar.nil?
          args[:bottom_appbar] = @bottom_appbar unless @bottom_appbar.nil?
        else
          # The root shell can own tab/bottom chrome, but pushed native WebView
          # screens should be standalone. Explicit nils prevent the client from
          # visually carrying root Scaffold slots across stacked views.
          args[:navigation_bar] = nil
          args[:bottom_appbar] = nil
        end
        Ruflet::UI::ControlFactory.build(:view, **args)
      end

      def screen_controls(screen)
        body = screen.body || screen.webview
        return [body] unless screen.rail

        [
          Ruflet::UI::ControlFactory.build(
            :row,
            controls: [screen.rail, body],
            expand: true,
            spacing: 0
          )
        ]
      end

      # Native chrome is opt-in: render an AppBar only when the app asks for one
      # (a title or actions) or the page declared one via `ruflet-appbar`
      # (screen.appbar_spec). With neither, the screen is a full-bleed webview —
      # the web page already renders its own header, so a native AppBar on top of
      # it just duplicates that chrome.
      def build_appbar(screen)
        spec = screen.appbar_spec
        actions = spec ? spec[:actions] : resolve_actions
        leading = spec ? spec[:leading] : nil
        has_title = spec ? true : !@title.to_s.strip.empty?
        return nil if !has_title && !leading && Array(actions).empty?

        args = { title: screen.title_text }
        if leading
          args[:leading] = leading
          args[:automatically_imply_leading] = false
        end
        args[:actions] = actions unless Array(actions).empty?
        Ruflet::UI::ControlFactory.build(:appbar, **args)
      end

      def title_for(screen)
        title = screen.appbar_spec&.fetch(:title, nil)
        title.nil? ? @title : title.to_s
      end

      def appbar_spec_from(spec)
        return nil unless spec.is_a?(Hash)

        title = spec["title"]
        leading = drawer_leading?(spec["leading"]) ? nil : build_chrome_button(spec["leading"])
        actions = Array(spec["actions"]).filter_map { |action| build_chrome_button(action) }
        return nil if title.to_s.strip.empty? && leading.nil? && actions.empty?

        { title: title.to_s, leading: leading, actions: actions }
      end

      def default_screen_appbar_spec(url)
        {
          title: title_from_url(url),
          leading: build_chrome_button({ "icon" => "close", "action" => "back" }),
          actions: []
        }
      end

      def title_from_url(url)
        path = URI.parse(url.to_s).path.to_s
        label = path.split("/").reject(&:empty?).last.to_s
        label = "Screen" if label.empty?
        label.tr("_-", " ").split.map(&:capitalize).join(" ")
      rescue URI::InvalidURIError
        "Screen"
      end

      def build_chrome_button(spec)
        spec = { "icon" => spec } unless spec.is_a?(Hash)
        icon = spec["icon"].to_s
        return nil if icon.empty?

        mode = (spec["action"] || spec["mode"] || "push").to_s
        url = spec["url"].to_s
        Ruflet::UI::ControlFactory.build(
          :icon_button,
          icon: icon,
          on_click: lambda do |_event|
            if mode == "back"
              pop
            elsif mode == "drawer"
              show_drawer
            elsif mode == "end_drawer"
              show_end_drawer
            elsif !url.empty?
              navigate_screen(url, mode, spec)
            end
          end
        )
      end

      def drawer_leading?(spec)
        spec.is_a?(Hash) && %w[drawer end_drawer].include?((spec["action"] || spec["mode"]).to_s)
      end

      def resolve_actions
        @actions.respond_to?(:call) ? @actions.call : @actions
      end

      # Rebuild a screen's view in place (e.g. after its AppBar changed, or the
      # root navigation bar was set) and repaint the stack.
      def rebuild_view(screen)
        screen.view = build_view(screen, root: screen.equal?(@screens.first))
        flush
      end

      def update_screen_appbar(screen)
        appbar = build_appbar(screen)
        return rebuild_view(screen) unless screen.view&.wire_id

        @page.update(screen.view, appbar: appbar)
      end

      def update_screen_drawer(screen, drawer:, end_drawer: nil)
        screen.drawer = drawer
        screen.end_drawer = end_drawer unless end_drawer.nil?
        return rebuild_view(screen) unless screen.view&.wire_id

        # Patch the drawer onto the already-mounted View in place, exactly like
        # update_screen_appbar / update_root_navigation_bar / update_screen_controls.
        # The previous `flush` re-sent the whole `views` list as full objects,
        # which made the client tear down and re-create the screen's WebView:
        # the body reloaded ("home loads twice"), the shimmer + appbar flashed
        # back in together, and the WebView's console channel detached so
        # bridge actions (share, copy, navigation) silently stopped working
        # after the first interaction. An in-place control patch keeps the
        # WebView — and its console channel — alive.
        props = { drawer: drawer }
        props[:end_drawer] = end_drawer unless end_drawer.nil?
        @page.update(screen.view, **props)
      end

      def update_screen_controls(screen)
        return rebuild_view(screen) unless screen.view&.wire_id

        @page.update(screen.view, controls: screen_controls(screen))
      end

      def update_root_navigation_bar
        root = @screens.first
        return unless root
        return rebuild_view(root) unless root.view&.wire_id

        @page.update(root.view, navigation_bar: @navigation_bar)
      end

      def build_loading_state
        return nil unless @loading
        return @loading if @loading.is_a?(Ruflet::Control)

        return build_text_loading_state(@loading) if text_loading?

        Ruflet::UI::ControlFactory.build(
          :container,
          bgcolor: "#F7F8FB",
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          padding: 24,
          visible: true,
          content: Ruflet::UI::ControlFactory.build(
            :shimmer,
            base_color: "#E5E7EB",
            highlight_color: "#F8FAFC",
            content: Ruflet::UI::ControlFactory.build(
              :column,
              controls: loading_bars,
              spacing: 18,
              expand: true
            )
          )
        )
      end

      def text_loading?
        @loading.is_a?(String) || @loading.to_sym == :text
      rescue NoMethodError
        false
      end

      def loading_label
        @loading.is_a?(String) ? @loading : "Loading..."
      end

      def build_text_loading_state(value)
        Ruflet::UI::ControlFactory.build(
          :container,
          bgcolor: "#F7F8FB",
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          alignment: "center",
          visible: true,
          content: Ruflet::UI::ControlFactory.build(:text, value: value.is_a?(String) ? value : loading_label)
        )
      end

      def loading_bars
        [
          loading_bar(width: 190, height: 28),
          loading_bar(width: 320, height: 16),
          loading_bar(width: 280, height: 16),
          loading_gap(14),
          loading_bar(width: 340, height: 86),
          loading_bar(width: 300, height: 86),
          loading_bar(width: 330, height: 86)
        ]
      end

      def loading_bar(width:, height:)
        Ruflet::UI::ControlFactory.build(
          :container,
          width: width,
          height: height,
          bgcolor: "#E5E7EB",
          border_radius: 10
        )
      end

      def loading_gap(height)
        Ruflet::UI::ControlFactory.build(:container, height: height)
      end

      def show_loading(screen)
        return unless screen&.loading
        return if screen.loading.props["visible"] == true

        screen.loading.props["visible"] = true
        @page.update(screen.loading, visible: true) if screen.loading.wire_id
      end

      def hide_loading(screen)
        return unless screen&.loading
        return if screen.loading.props["visible"] == false

        screen.loading.props["visible"] = false
        @page.update(screen.loading, visible: false) if screen.loading.wire_id
      end

      def reconcile_loading_visibility
        @screens.each do |screen|
          next unless screen.loading&.wire_id
          next unless screen.loading.props.key?("visible")

          @page.update(screen.loading, visible: screen.loading.props["visible"])
        end
      rescue StandardError
        nil
      end

      # --- Bridge ------------------------------------------------------------

      def inject_bridge(screen)
        screen.webview.run_javascript(self.class.bridge_js(screen_links: @screen_links)) if screen.webview.respond_to?(:run_javascript)
      rescue StandardError
        nil
      end

      def normalize_screen_links(screen_links)
        Array(screen_links).map do |entry|
          if entry.is_a?(Array)
            href, payload = entry
            { "href" => href.to_s, "payload" => stringify_keys(payload || {}) }
          elsif entry.is_a?(Hash)
            stringify_keys(entry)
          end
        end.compact
      end

      def stringify_keys(value)
        case value
        when Hash
          value.each_with_object({}) { |(key, nested), out| out[key.to_s] = stringify_keys(nested) }
        when Array
          value.map { |nested| stringify_keys(nested) }
        else
          value
        end
      end

      # Force JavaScript on for a (mounted) webview. The mobile client only
      # enables JS through this invoke method — the enable_javascript prop is a
      # no-op there — so we call it on every page start.
      def enable_js(webview)
        webview.set_javascript_mode("unrestricted") if webview.respond_to?(:set_javascript_mode)
      rescue StandardError
        nil
      end

      def handle_message(screen, message)
        return if message.nil?

        if message.start_with?(TITLE_PREFIX)
          update_title(screen, message[TITLE_PREFIX.length..])
        elsif message.start_with?(ACTION_PREFIX)
          spec = parse_json(message[ACTION_PREFIX.length..])
          dispatch_action(spec) if spec
        elsif message.start_with?(APPBAR_PREFIX)
          spec = parse_json(message[APPBAR_PREFIX.length..])
          apply_appbar(screen, spec) if spec
        elsif message.start_with?(BOTTOMNAV_PREFIX)
          spec = parse_json(message[BOTTOMNAV_PREFIX.length..])
          apply_bottomnav(spec) if spec
        elsif message.start_with?(DRAWER_PREFIX)
          spec = parse_json(message[DRAWER_PREFIX.length..])
          apply_drawer(screen, spec) if spec
        elsif message.start_with?(RAIL_PREFIX)
          spec = parse_json(message[RAIL_PREFIX.length..])
          apply_rail(screen, spec) if spec
        end
      end

      def parse_json(raw)
        value = JSON.parse(raw.to_s)
        value.is_a?(Hash) ? value : nil
      rescue JSON::ParserError
        nil
      end

      def update_title(screen, value)
        return unless screen.title_text&.wire_id
        return if screen.appbar_spec

        value = value.to_s
        return if screen.title_text.props["value"] == value

        @page.update(screen.title_text, value: value)
      end

      # --- Declared actions --------------------------------------------------

      # Route a `ruflet-action` element (or RufletNative call) to native.
      def dispatch_action(spec)
        component = (spec["component"] || spec["type"]).to_s
        action = spec["action"].to_s

        case component
        when "navigation", "navigate"
          navigate_screen(spec["url"], action, spec)
        when "dialog"
          show_native_dialog(spec)
        when "toast"
          show_toast(spec)
        when "sheet"
          present_sheet(spec["url"])
        when "drawer"
          show_drawer
        when "share"
          share_content(spec)
        when "clipboard", "copy"
          copy_to_clipboard(spec)
        when "launcher", "url", "url_launcher"
          launch_external_url(spec)
        when "haptic", "haptic_feedback"
          haptic_feedback(spec)
        else
          case action
          when "dialog" then show_native_dialog(spec)
          when "toast"  then show_toast(spec)
          when "sheet"  then present_sheet(spec["url"])
          when "drawer" then show_drawer
          when "end_drawer" then show_end_drawer
          when "share" then share_content(spec)
          when "copy", "clipboard" then copy_to_clipboard(spec)
          when "launch", "url", "url_launcher" then launch_external_url(spec)
          when "haptic", "haptic_feedback" then haptic_feedback(spec)
          when "back"   then pop
          when "navigate" then navigate_screen(spec["url"], spec["mode"] || "push", spec)
          when "push", "replace", "root" then navigate_screen(spec["url"], action, spec)
          end
        end
      end

      # --- Native services ---------------------------------------------------

      def share_content(spec)
        clear_transient_overlays
        files = spec["files"]
        uri = share_uri_for(spec)
        text = spec["text"] || spec["message"] || spec["content"]

        if files
          @page.share_files(files, text: text, title: spec["title"], subject: spec["subject"])
        elsif uri && text.to_s.empty?
          @page.share_uri(uri)
        else
          @page.share_text(text.to_s, title: spec["title"], subject: spec["subject"])
        end
        haptic_feedback({ "style" => "selection" }) if spec["haptic"]
      rescue StandardError
        nil
      end

      def copy_to_clipboard(spec)
        clear_transient_overlays
        value = spec["text"] || spec["value"] || spec["content"] || spec["message"] || spec["url"]
        return if value.to_s.empty?

        @page.set_clipboard(value)
        show_toast(
          "message" => spec["toast"].to_s,
          "duration" => (spec["toast_duration"] || spec["duration"] || 900).to_s
        ) unless spec["toast"].to_s.empty?
        haptic_feedback({ "style" => "selection" }) if spec.fetch("haptic", true)
      rescue StandardError
        nil
      end

      def share_uri_for(spec)
        uri = spec["uri"] || spec["url"]
        return current_screen_url if uri.to_s.empty? || uri.to_s == "#"

        uri
      end

      def current_screen_url
        @screens.last&.url || @start_url
      end

      def same_url?(left, right)
        absolute_url(left).to_s == absolute_url(right).to_s
      end

      def clear_transient_overlays
        @page.snackbar = nil if @page.respond_to?(:snackbar=)
      rescue StandardError
        nil
      end

      def launch_external_url(spec)
        url = spec["url"] || spec["href"] || spec["uri"]
        return if url.to_s.empty?

        @page.launch_url(url.to_s, mode: spec["mode"])
      rescue StandardError
        nil
      end

      def haptic_feedback(spec)
        style = (spec["style"] || spec["kind"] || spec["impact"] || "selection").to_s
        case style
        when "heavy" then @page.heavy_impact
        when "medium" then @page.medium_impact
        when "light" then @page.light_impact
        when "vibrate" then @page.vibrate
        else @page.selection_click
        end
      rescue StandardError
        nil
      end

      # Screen navigation modes:
      #   push    - push the URL as a new webview screen (default)
      #   replace - swap the current top screen for the URL
      #   root    - reset the stack to a single root screen at the URL (tab-like)
      #   sheet   - present the URL as a bottom-sheet web modal
      #   back    - pop the top screen
      def navigate_screen(url, mode, spec = nil)
        url = absolute_url(url)
        mode = mode.to_s
        mode = "push" if mode.empty?
        if bottomnav_destination?(url) && !%w[back sheet].include?(mode)
          mode = "root"
          spec = bottomnav_appbar_spec(url, spec)
        end
        case mode
        when "back"    then pop
        when "root"    then go_webview(url, spec: spec)
        when "replace" then replace_webview(url, spec: spec)
        when "sheet"   then present_sheet(url)
        else                push_webview(url, spec: spec)
        end
      end

      # Reset to a single root screen (the root keeps the navigation bar / bottom
      # app bar). Used by `mode: root` and bottom-nav tab switches.
      #
      # ruflet_rails renders everything over the WebSocket, so switching tabs
      # must NOT tear down and re-create the native shell — that re-mounts the
      # AppBar and NavigationBar and makes them flash on every tab. The shell
      # (AppBar + tabs) is already there; only the body should change. So when a
      # root WebView is already mounted we keep it and just navigate its body to
      # the new URL (load_request). The page reports its own chrome on load and
      # the AppBar title is patched in place — never rebuilt.
      def go_webview(url, spec: nil)
        url = absolute_url(url)
        return if url.empty?

        root = @screens.first
        if root&.webview&.wire_id
          collapse_to_root(root)
          navigate_root_body(root, url, spec)
        else
          @screens.clear
          push_webview(url, root: true, spec: spec)
        end
      end

      # Drop any screens pushed on top of the root without disturbing the root
      # view (so its AppBar / NavigationBar stay mounted).
      def collapse_to_root(root)
        return if @screens.size <= 1

        @screens = [root]
        flush
      end

      # Reload only the body of the mounted root screen, keeping the AppBar and
      # NavigationBar in place.
      #
      # We build a BRAND-NEW WebView body and swap it into the existing view with
      # an in-place control patch (update_screen_controls), rather than calling
      # webview.load_request on the old WebView. load_request is delivered as a
      # control *invoke*, and the client WebView's invoke listener is registered
      # in its State.initState — so it is dropped whenever a push/pop re-sends the
      # view stack and the WebView control is re-created. That is exactly why the
      # bottom nav "did nothing" after a drawer navigation: the tap reached the
      # server, go_webview ran, but load_request never landed on the client. A
      # fresh WebView mounts with its own listeners and loads the URL itself, and
      # a controls patch never touches the AppBar/NavigationBar (no flash, their
      # listeners survive). The new body carries its own loading shimmer, so the
      # body shows the skeleton while the page streams in.
      def navigate_root_body(screen, url, spec)
        screen.url = url
        screen.webview = build_webview(screen)
        screen.loading = build_loading_state
        screen.body = build_webview_body(screen)
        apply_spec_chrome(screen, spec)
        sync_drawer_selection(screen)
        update_screen_controls(screen)
        sync_root_navigation_bar_selection
      end

      # Apply declared chrome onto the reused root view in place. A title-only
      # hint (a tab switch carries the destination's label) just repaints the
      # AppBar title — the instant you tap a tab the AppBar reads that tab's name
      # instead of the route you left, with no AppBar rebuild/flash. A richer spec
      # (explicit leading/actions) rebuilds the AppBar as before.
      def apply_spec_chrome(screen, spec)
        new_spec = appbar_spec_from(spec)
        return unless new_spec

        if new_spec[:leading].nil? && Array(new_spec[:actions]).empty?
          update_screen_title(screen, new_spec[:title].to_s)
          return
        end

        screen.appbar_spec = new_spec
        screen.appbar_signature = nil
        screen.title_text = Ruflet::UI::ControlFactory.build(:text, value: title_for(screen))
        update_screen_appbar(screen)
      end

      # Repaint just the AppBar's title text in place (no AppBar rebuild).
      def update_screen_title(screen, title)
        return if title.empty?

        text = screen.title_text
        return unless text

        if text.wire_id
          return if text.props["value"] == title

          @page.update(text, value: title)
        else
          text.props["value"] = title
        end
      end

      # Replace the current top screen with a new one (no extra back step).
      def replace_webview(url, spec: nil)
        url = absolute_url(url)
        return if url.empty?

        root = @screens.size <= 1
        @screens.pop unless @screens.empty?
        push_webview(url, root: root, spec: spec)
      end

      # --- HTML-declared native chrome ---------------------------------------

      # The page declared a `ruflet-appbar`: give the reporting screen a native
      # AppBar with that title and any action buttons (each navigates on tap).
      def apply_appbar(screen, spec)
        return unless screen

        spec = bottomnav_appbar_spec(screen.url, spec) if screen.equal?(@screens.first) && bottomnav_destination?(screen.url)
        remember_appbar_spec(screen.url, spec)
        signature = chrome_signature(spec)
        return if screen.appbar_signature == signature

        title = spec["title"].to_s
        screen.title_text = Ruflet::UI::ControlFactory.build(:text, value: title)
        leading = drawer_leading?(spec["leading"]) ? nil : build_chrome_button(spec["leading"])
        actions = Array(spec["actions"]).filter_map { |action| build_chrome_button(action) }
        screen.appbar_spec = { title: title, leading: leading, actions: actions }
        screen.appbar_signature = signature
        update_screen_appbar(screen)
      end

      # The page declared a `ruflet-bottomnav`: build a native NavigationBar on
      # the root view. Selecting a destination switches to that URL as a fresh
      # root (tab semantics).
      def apply_bottomnav(spec)
        @bottomnav_spec = spec
        return unless buildable_bottomnav?(spec)
        signature = chrome_signature(spec)
        return if @bottomnav_signature == signature

        @navigation_bar = build_bottomnav(spec)
        @bottomnav_signature = signature
        update_root_navigation_bar
      end

      # The page declared a `ruflet-drawer`: build a native NavigationDrawer on
      # the reporting screen. Selecting a destination closes the drawer first,
      # then applies that item's requested navigation mode.
      def apply_drawer(screen, spec)
        return unless screen

        @drawer_spec = spec
        items = Array(spec["items"])
        urls = items.map { |item| absolute_url(item["url"]) }
        modes = items.map { |item| (item["action"] || item["mode"] || "root").to_s }
        destinations = items.each_with_index.filter_map do |item, index|
          build_drawer_destination(item, selected: default_drawer_item_selected?(item, screen), on_click: lambda do |_event|
            select_drawer_item(screen, items, urls, modes, index)
          end)
        end
        return if destinations.empty?

        signature = chrome_signature(spec)
        if screen.drawer_signature == signature
          if @drawer_open_requested
            @drawer_open_requested = false
            show_drawer
          end
          return
        end

        drawer = Ruflet::UI::ControlFactory.build(
          :navigationdrawer,
          controls: destinations,
          selected_index: items.index { |item| item["selected"] } || 0,
          on_change: lambda do |event|
            index = navigation_index(event)
            select_drawer_item(screen, items, urls, modes, index)
          end
        )
        screen.drawer_signature = signature
        update_screen_drawer(screen, drawer: drawer)
        if @drawer_open_requested
          @drawer_open_requested = false
          show_drawer
        end
      end

      # The page declared a `ruflet-rail`: desktop/tablet native navigation.
      # Unlike drawer/bottom nav, NavigationRail is a control, so the WebView
      # body is wrapped in a Row with the rail on the left.
      def apply_rail(screen, spec)
        return unless screen

        items = Array(spec["items"])
        destinations = items.filter_map { |item| build_rail_destination(item) }
        return if destinations.length < 2

        signature = chrome_signature(spec)
        return if screen.rail_signature == signature

        urls = items.map { |item| absolute_url(item["url"]) }
        modes = items.map { |item| (item["action"] || item["mode"] || "root").to_s }
        rail_args = {
          destinations: destinations,
          selected_index: items.index { |item| item["selected"] } || 0,
          label_type: spec["label_type"] || spec["labelType"] || "all",
          on_change: lambda do |event|
            index = navigation_index(event)
            target = urls[index].to_s
            next if target.empty?

            mode = modes[index]
            spec = mode == "root" ? { "title" => items[index]["label"].to_s } : nil
            navigate_screen(target, mode, spec)
          end
        }
        rail_args[:extended] = !!spec["extended"] unless spec["extended"].nil?
        rail_args[:min_width] = spec["min_width"].to_i if spec["min_width"]
        rail_args[:min_extended_width] = spec["min_extended_width"].to_i if spec["min_extended_width"]
        screen.rail = Ruflet::UI::ControlFactory.build(:navigationrail, **rail_args)
        screen.rail_signature = signature
        update_screen_controls(screen)
      end

      def chrome_signature(spec)
        JSON.generate(canonicalize(spec))
      end

      def canonicalize(value)
        case value
        when Hash
          value.keys.map(&:to_s).sort.each_with_object({}) do |key, out|
            original_key = value.key?(key) ? key : key.to_sym
            out[key] = canonicalize(value[original_key])
          end
        when Array
          value.map { |item| canonicalize(item) }
        else
          value
        end
      end

      def build_destination(item)
        icon = item["icon"].to_s
        return nil if icon.empty?

        Ruflet::UI::ControlFactory.build(
          :navigation_bar_destination, icon: icon, label: item["label"].to_s
        )
      end

      def buildable_bottomnav?(spec)
        Array(spec["items"]).filter_map { |item| build_destination(item) }.length >= 2
      end

      def build_bottomnav(spec)
        items = Array(spec["items"])
        destinations = items.filter_map { |item| build_destination(item) }
        urls = items.map { |item| absolute_url(item["url"]) }

        Ruflet::UI::ControlFactory.build(
          :navigation_bar,
          destinations: destinations,
          selected_index: bottomnav_selected_index(items),
          on_change: lambda do |event|
            index = navigation_index(event)
            target = urls[index].to_s
            next if target.empty? || same_url?(target, current_screen_url)

            # Carry the tab's label so the AppBar shows the destination's name
            # immediately, unless the destination page already declared a more
            # specific native AppBar (e.g. Home tab label -> Demo app title).
            go_webview(target, spec: bottomnav_appbar_spec(target, { "title" => items[index]["label"].to_s }))
          end
        )
      end

      def bottomnav_selected_index(items)
        urls = items.map { |item| absolute_url(item["url"]) }
        urls.index { |candidate| same_url?(candidate, current_screen_url) } ||
          items.index { |item| item["selected"] } || 0
      end

      def bottomnav_destination?(url)
        bottomnav_item_for(url) != nil
      end

      def bottomnav_label_for(url)
        bottomnav_item_for(url)&.fetch("label", nil).to_s
      end

      def bottomnav_appbar_spec(url, spec)
        declared = appbar_spec_for_url(url)
        label = bottomnav_label_for(url)
        title =
          if declared && !declared["title"].to_s.empty?
            declared["title"].to_s
          elsif spec.is_a?(Hash) && !spec["title"].to_s.empty?
            spec["title"].to_s
          else
            label
          end
        actions = declared ? declared["actions"] : (spec.is_a?(Hash) ? spec["actions"] : nil)
        { "title" => title, "leading" => { "action" => "drawer" }, "actions" => actions }.compact
      end

      def bottomnav_item_for(url)
        items = Array(@bottomnav_spec && @bottomnav_spec["items"])
        items.find { |item| same_url?(absolute_url(item["url"]), url) }
      end

      def remember_appbar_spec(url, spec)
        return unless spec.is_a?(Hash)

        key = appbar_spec_key(url)
        @appbar_specs_by_url[key] = canonicalize(spec) if key
      end

      def appbar_spec_for_url(url)
        key = appbar_spec_key(url)
        key && @appbar_specs_by_url[key]
      end

      def appbar_spec_key(url)
        uri = URI.parse(absolute_url(url))
        path = uri.path.to_s.empty? ? "/" : uri.path.to_s
        "#{uri.scheme}://#{uri.host}:#{uri.port}#{path}"
      rescue URI::InvalidURIError
        nil
      end

      def refresh_root_navigation_bar
        return unless @bottomnav_spec && buildable_bottomnav?(@bottomnav_spec)

        # A drawer push/back can leave the native bottom bar visually mounted
        # while its event channel is stale. Replacing only the NavigationBar
        # control after the stack settles gives the client fresh callbacks
        # without reloading the WebView body or flashing the AppBar.
        @navigation_bar = build_bottomnav(@bottomnav_spec)
        update_root_navigation_bar
      end

      def refresh_root_drawer
        root = @screens.first
        return unless root && @drawer_spec

        # A push/pop reserializes the root view under the pushed route. The
        # drawer can remain visually mounted but lose its live change callback,
        # so rebuild only the drawer control after returning to root.
        root.drawer_signature = nil
        apply_drawer(root, @drawer_spec)
      end

      def sync_root_navigation_bar_selection
        return unless @navigation_bar&.wire_id && @bottomnav_spec

        index = bottomnav_selected_index(Array(@bottomnav_spec["items"]))
        return if @navigation_bar.props["selected_index"] == index

        @navigation_bar.props["selected_index"] = index
        @page.update(@navigation_bar, selected_index: index)
      end

      def build_drawer_destination(item, selected: false, on_click: nil)
        icon = item["icon"].to_s
        return nil if icon.empty?

        Ruflet::UI::ControlFactory.build(
          :list_tile,
          leading: Ruflet::UI::ControlFactory.build(:icon, icon: icon),
          title: Ruflet::UI::ControlFactory.build(:text, value: item["label"].to_s),
          selected: selected,
          on_click: on_click
        )
      end

      def select_drawer_item(screen, items, urls, modes, index)
        close_drawer(screen, retry_close: true)
        target = urls[index].to_s
        return if target.empty?

        if same_url?(target, current_screen_url)
          sync_drawer_selection(screen)
          return
        end

        mode = modes[index]
        # Only a tab (root) switch carries a title hint to repaint the AppBar
        # title in place. A push keeps its own declared chrome (notably the
        # back button), so we must NOT force a title-only AppBar on it.
        spec = mode == "root" ? { "title" => items[index]["label"].to_s } : nil
        navigate_screen(target, mode, spec)
        close_drawer(@screens.last, retry_close: true)
        # The drawer must mark the route we ended up on, never the item just
        # tapped. A push item (e.g. Settings) is a detail screen, not a tab,
        # so the current tab stays selected instead of leaving two
        # destinations highlighted at once.
        sync_drawer_selection(screen)
      end

      def default_drawer_item_selected?(item, screen)
        same_url?(absolute_url(item["url"]), screen.url) || !!item["selected"]
      end

      def build_rail_destination(item)
        icon = item["icon"].to_s
        return nil if icon.empty?

        Ruflet::UI::ControlFactory.build(
          :navigation_rail_destination, icon: icon, label: item["label"].to_s
        )
      end

      def navigation_index(event)
        data = event.respond_to?(:data) ? event.data : event
        return (data["selected_index"] || data["value"] || data["i"] || 0).to_i if data.is_a?(Hash)

        data.to_i
      end

      # Keep the drawer's highlighted destination in sync with the route we are
      # actually on. Selecting a drawer item (or tapping a tab) leaves the drawer
      # marking that item, and the screen's WebView is not re-reported on a tab
      # switch or a back navigation — so without this the drawer keeps
      # highlighting a route we already left. Re-point the selection to the item
      # matching the current URL (or the declared default). Called after every
      # root navigation and on back.
      def sync_drawer_selection(screen)
        drawer = screen&.drawer
        return unless drawer&.wire_id

        index = default_drawer_index(screen)
        return if drawer.props["selected_index"] == index

        drawer.props["selected_index"] = index
        @page.update(drawer, selected_index: index)
      end

      def default_drawer_index(screen)
        items = Array(@drawer_spec && @drawer_spec["items"])
        return 0 if items.empty?

        urls = items.map { |item| absolute_url(item["url"]) }
        urls.index { |candidate| same_url?(candidate, screen.url) } ||
          items.index { |item| item["selected"] } || 0
      end

      def show_drawer
        screen = @screens.last
        return unless screen&.view&.wire_id
        unless screen.drawer || screen.view.props["drawer"]
          if @drawer_spec
            @drawer_open_requested = true
            apply_drawer(screen, @drawer_spec)
            return
          end
          @drawer_open_requested = true
          return
        end

        invoke_drawer_when_ready(screen, "show_drawer")
      rescue StandardError
        nil
      end

      def close_drawer(screen = nil, retry_close: false)
        @drawer_open_requested = false
        targets = [screen, @screens.last].compact.uniq
        return if targets.empty?

        targets.each { |target| invoke_close_drawer(target) }
        retry_close_drawer(targets) if retry_close
      rescue StandardError
        nil
      end

      def show_end_drawer
        screen = @screens.last
        return unless screen&.view&.wire_id

        invoke_drawer_when_ready(screen, "show_end_drawer")
      rescue StandardError
        nil
      end

      # Drawer chrome can be patched into an already-mounted View from an ERB
      # report. Flutter rebuilds that Scaffold asynchronously, so invoking
      # openDrawer in the same client frame can no-op against the previous
      # Scaffold. Send the invoke on the next Ruby tick; if the current runtime
      # cannot spawn, fall back to the direct invoke.
      def invoke_drawer_when_ready(screen, method_name)
        Thread.new do
          [0.05, 0.15, 0.3].each do |delay|
            sleep delay
            next unless screen&.view&.wire_id

            @page.invoke(screen.view, method_name)
            @page.invoke_current_view(method_name, timeout: 10, on_result: nil) if @page.respond_to?(:invoke_current_view)
          end
        rescue StandardError
          nil
        end
      rescue StandardError
        @page.invoke(screen.view, method_name)
      end

      def invoke_close_drawer(screen)
        return unless screen&.view&.wire_id

        @page.invoke(screen.view, "close_drawer")
      end

      def retry_close_drawer(screens)
        Thread.new do
          [0.05, 0.15].each do |delay|
            sleep delay
            screens.each { |screen| invoke_close_drawer(screen) }
          end
        rescue StandardError
          nil
        end
      rescue StandardError
        nil
      end

      # --- Native dialog / toast ---------------------------------------------

      # `ruflet-action="dialog"`: open a native AlertDialog. A confirm button
      # (when given) navigates; OK just dismisses.
      def show_native_dialog(spec)
        title = spec["title"].to_s
        content = spec["content"].to_s
        actions = []

        confirm = spec["confirm"].to_s
        unless confirm.empty?
          url = spec["url"].to_s
          mode = (spec["action"] || spec["mode"] || "push").to_s
          actions << Ruflet::UI::ControlFactory.build(
            :text_button,
            content: confirm,
            on_click: lambda do |_event|
              close_dialog
              navigate_screen(url, mode) unless url.empty?
            end
          )
        end
        actions << Ruflet::UI::ControlFactory.build(
          :text_button, content: "OK", on_click: ->(_event) { close_dialog }
        )

        args = { actions: actions, open: true, adaptive: adaptive?(spec), on_dismiss: ->(_event) { @dialog = nil } }
        args[:title] = Ruflet::UI::ControlFactory.build(:text, value: title) unless title.empty?
        args[:content] = Ruflet::UI::ControlFactory.build(:text, value: content) unless content.empty?
        @dialog = Ruflet::UI::ControlFactory.build(:alert_dialog, **args)
        @page.show_dialog(@dialog)
      end

      def close_dialog
        return unless @dialog

        @page.update(@dialog, open: false)
        @dialog = nil
      end

      # `ruflet-action="toast"`: show a native SnackBar.
      def show_toast(spec)
        message = spec["message"].to_s
        return if message.empty?

        args = { content: Ruflet::UI::ControlFactory.build(:text, value: message), open: true,
                 adaptive: adaptive?(spec) }
        duration = spec["duration"].to_s
        args[:duration] = duration.to_i if duration =~ /\A\d+\z/
        @page.snackbar = Ruflet::UI::ControlFactory.build(:snack_bar, **args)
      end

      # --- Bottom-sheet modal (web content) ----------------------------------

      SHEET_PADDING      = 20   # inset the page from the sheet edges (top clears the handle)
      SHEET_HEIGHT_RATIO = 0.82 # short enough to leave a clear peek of the screen

      # `ruflet-action="sheet"`: present a URL as a bottom-sheet modal. It must
      # READ as a modal — a sheet that slides up over the current screen with a
      # drag handle, rounded top, and a clear peek of the page behind it, not a
      # fullscreen container indistinguishable from a pushed page. The webview has
      # no intrinsic size, so the card is explicitly sized to leave that peek; the
      # uniform padding then insets the page (the top inset clears the handle).
      def present_sheet(url)
        url = absolute_url(url)
        return if url.empty?

        sheet_webview = nil
        sheet_webview = Ruflet::UI::ControlFactory.build(
          :webview, url: url, method: "get", enable_javascript: true,
          on_page_started: ->(_event) { enable_js(sheet_webview) }
        )
        card = Ruflet::UI::ControlFactory.build(
          :container,
          content: sheet_webview,
          width: sheet_card_width,
          height: sheet_card_height,
          padding: SHEET_PADDING
        )
        @sheet = Ruflet::UI::ControlFactory.build(
          :bottomsheet,
          open: true,
          adaptive: true,
          dismissible: true,        # tap the peek above the sheet to dismiss
          draggable: true,          # ...or drag the handle down to dismiss
          scrollable: true,         # isScrollControlled: let the sheet grow tall
          show_drag_handle: true,   # the grab handle that signals "modal"
          use_safe_area: true,
          content: card,
          on_dismiss: ->(_event) { @sheet = nil }
        )
        @page.bottom_sheet = @sheet
        @page.update
      end

      # Card dimensions from the live viewport (the client reports it via the
      # resize event). Full width; height leaves a clear peek of the screen above
      # the sheet. Falls back to sensible phone dimensions before the first
      # resize report.
      def sheet_card_width
        numeric_or(@page.respond_to?(:width) ? @page.width : nil, 430.0).round
      end

      def sheet_card_height
        viewport = numeric_or(@page.respond_to?(:height) ? @page.height : nil, 800.0)
        (viewport * SHEET_HEIGHT_RATIO).round
      end

      def numeric_or(value, fallback)
        value.is_a?(Numeric) && value.positive? ? value.to_f : fallback
      end

      def adaptive?(spec)
        return false if spec.is_a?(Hash) && spec["adaptive"] == false

        true
      end

      def absolute_url(url)
        url = url.to_s
        return "" if url.empty?
        return url if URI.parse(url).absolute?

        URI.join(current_url, url).to_s
      rescue URI::InvalidURIError
        url
      end

      def current_url
        @screens.last&.url || @start_url
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
