# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # WebView control — parity with Flet's WebView
        # (https://flet.dev/docs/controls/webview/).
        #
        # Properties: url, bgcolor, prevent_links, plus the usual layout props.
        # Events: on_page_started, on_page_ended, on_web_resource_error,
        #   on_progress, on_url_change, on_scroll, on_console_message,
        #   on_javascript_alert_dialog.
        # Methods (invoked over the wire on a mounted control): reload, go_back,
        #   go_forward, can_go_back, can_go_forward, run_javascript, load_html,
        #   load_request, load_file, scroll_to, scroll_by, clear_cache,
        #   clear_local_storage, enable_zoom, disable_zoom, set_javascript_mode,
        #   get_current_url, get_title, get_user_agent.
        #
        # Platform note: the native webview (and therefore run_javascript and the
        # events/methods) runs on iOS, Android and macOS. On web it falls back to
        # an <iframe>, which cannot run the methods and which most external sites
        # block via X-Frame-Options/CSP — embed your own same-origin pages there.
        class WebViewControl < Ruflet::Control
          TYPE = "WebView".freeze
          WIRE = "WebView".freeze

          def initialize(id: nil, bgcolor: nil, data: nil, enable_javascript: nil, expand: nil,
                         height: nil, key: nil, method: nil, opacity: nil, prevent_links: nil,
                         rtl: nil, tooltip: nil, url: nil, visible: nil, width: nil,
                         on_page_ended: nil, on_page_started: nil, on_web_resource_error: nil,
                         on_progress: nil, on_url_change: nil, on_scroll: nil,
                         on_console_message: nil, on_javascript_alert_dialog: nil)
            props = {}
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:data] = data unless data.nil?
            props[:enable_javascript] = enable_javascript unless enable_javascript.nil?
            props[:expand] = expand unless expand.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:method] = method unless method.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:prevent_links] = prevent_links unless prevent_links.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:url] = url unless url.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_page_ended] = on_page_ended unless on_page_ended.nil?
            props[:on_page_started] = on_page_started unless on_page_started.nil?
            props[:on_web_resource_error] = on_web_resource_error unless on_web_resource_error.nil?
            props[:on_progress] = on_progress unless on_progress.nil?
            props[:on_url_change] = on_url_change unless on_url_change.nil?
            props[:on_scroll] = on_scroll unless on_scroll.nil?
            props[:on_console_message] = on_console_message unless on_console_message.nil?
            props[:on_javascript_alert_dialog] = on_javascript_alert_dialog unless on_javascript_alert_dialog.nil?
            super(type: TYPE, id: id, **props)
          end

          # --- Navigation --------------------------------------------------

          def reload = invoke_webview_method("reload")
          def go_back = invoke_webview_method("go_back")
          def go_forward = invoke_webview_method("go_forward")

          def can_go_back(timeout: 10, &on_result)
            invoke_webview_method("can_go_back", timeout: timeout, on_result: on_result)
          end

          def can_go_forward(timeout: 10, &on_result)
            invoke_webview_method("can_go_forward", timeout: timeout, on_result: on_result)
          end

          # --- Loading content ---------------------------------------------

          def load_request(url, method: "get")
            invoke_webview_method("load_request", { "url" => url.to_s, "method" => method.to_s })
          end

          def load_html(value, base_url: nil)
            args = { "value" => value.to_s }
            args["base_url"] = base_url.to_s unless base_url.nil?
            invoke_webview_method("load_html", args)
          end

          def load_file(path)
            invoke_webview_method("load_file", { "path" => path.to_s })
          end

          # --- JavaScript injection ---------------------------------------

          # Run arbitrary JS inside the page — e.g. hide a node so a native
          # control can take its place:
          #   webview.run_javascript("document.getElementById('banner').remove()")
          def run_javascript(value)
            invoke_webview_method("run_javascript", { "value" => value.to_s })
          end

          def set_javascript_mode(mode)
            invoke_webview_method("set_javascript_mode", { "mode" => mode.to_s })
          end

          # --- Scrolling ---------------------------------------------------

          def scroll_to(x, y)
            invoke_webview_method("scroll_to", { "x" => x.to_i, "y" => y.to_i })
          end

          def scroll_by(x, y)
            invoke_webview_method("scroll_by", { "x" => x.to_i, "y" => y.to_i })
          end

          # --- Storage / zoom ----------------------------------------------

          def clear_cache = invoke_webview_method("clear_cache")
          def clear_local_storage = invoke_webview_method("clear_local_storage")
          def enable_zoom = invoke_webview_method("enable_zoom")
          def disable_zoom = invoke_webview_method("disable_zoom")

          # --- Introspection (result delivered to the block) ---------------

          def get_current_url(timeout: 10, &on_result)
            invoke_webview_method("get_current_url", timeout: timeout, on_result: on_result)
          end

          def get_title(timeout: 10, &on_result)
            invoke_webview_method("get_title", timeout: timeout, on_result: on_result)
          end

          def get_user_agent(timeout: 10, &on_result)
            invoke_webview_method("get_user_agent", timeout: timeout, on_result: on_result)
          end

          private

          def invoke_webview_method(name, args = nil, timeout: 10, on_result: nil)
            page = runtime_page
            unless page && wire_id
              raise "WebView ##{id} is not mounted yet — add it to the page before calling #{name}."
            end

            page.invoke(self, name, args: args, timeout: timeout, on_result: on_result)
          end
        end
      end
    end
  end
end
