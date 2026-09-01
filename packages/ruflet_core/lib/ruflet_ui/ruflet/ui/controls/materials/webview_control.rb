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
        # Platform note: the native webview runs on iOS, Android, macOS, Windows,
        # and Linux. Linux distributions must provide WebKitGTK 4.1. On web it
        # uses an iframe, so browser cross-origin restrictions still apply.
        class WebViewControl < Ruflet::Control
          TYPE = "WebView".freeze
          WIRE = "WebView".freeze
          KEYWORDS = [].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each { |key, value| compact[key] = value unless value.nil? }
            super(type: TYPE, id: id, **compact)
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
