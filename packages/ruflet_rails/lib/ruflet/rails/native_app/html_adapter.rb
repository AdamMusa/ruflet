# frozen_string_literal: true

module Ruflet
  module Rails
    class NativeApp
      # Tiny WebView-side adapter: read ERB-rendered `data-ruflet-*`
      # declarations and report them so Ruby can build normal Ruflet controls.
      HTML_ADAPTER_JS = <<~JS
        (function () {
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

          function syncChrome() {
            var bar = document.querySelector("[ruflet-appbar],[data-ruflet-appbar]");
            if (bar) {
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
                // Carry the whole payload through (e.g. the title/leading the
                // action declares for the screen it pushes), then normalize the
                // icon/url/action the AppBar button itself needs.
                var entry = Object.assign({}, icon);
                entry.icon = icon.icon || attr(el, "ruflet-icon");
                entry.url = el.getAttribute("href") || icon.url || attr(el, "ruflet-url") || "";
                entry.action = icon.action || attr(el, "ruflet-action") || "push";
                actions.push(entry);
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
          }
          syncChrome();

          if (window.__rufletHtmlAdapterBound) return;
          window.__rufletHtmlAdapterBound = true;

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
          }, true);
        })();
      JS

      ACTION_PREFIX    = "ruflet:action:"
      APPBAR_PREFIX    = "ruflet:appbar:"
      BOTTOMNAV_PREFIX = "ruflet:bottomnav:"
      DRAWER_PREFIX    = "ruflet:drawer:"
      RAIL_PREFIX      = "ruflet:rail:"

      def self.html_adapter_js
        HTML_ADAPTER_JS
      end

      private

      # --- HTML adapter ------------------------------------------------------

      def inject_html_adapter(screen)
        screen.webview.run_javascript(self.class.html_adapter_js) if screen.webview.respond_to?(:run_javascript)
      rescue StandardError
        nil
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

        if message.start_with?(ACTION_PREFIX)
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
    end
  end
end
