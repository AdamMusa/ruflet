# frozen_string_literal: true

module Showcase
  module SectionsMedia
    def build_webview(page, _status)
      # On the web the native webview becomes an <iframe>, which most sites
      # (including ruflet.dev via X-Frame-Options) refuse to be embedded in.
      return unsupported_feature_panel(page, "WebView", "webview") unless feature_supported?(page, "webview")

      webview_control = web_view(
        url: "https://ruflet.dev/",
        method: "get",
        expand: true
      )
      container(
        expand: true,
        content: webview_control
      )
    end
  end
end
