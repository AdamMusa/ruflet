# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class WebViewControl < Ruflet::Control
          TYPE = "WebView".freeze
          WIRE = "WebView".freeze

          def initialize(id: nil, bgcolor: nil, data: nil, enable_javascript: nil, expand: nil, height: nil, key: nil, method: nil, opacity: nil, rtl: nil, tooltip: nil, url: nil, visible: nil, width: nil, on_page_ended: nil, on_page_started: nil, on_web_resource_error: nil)
            props = {}
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:data] = data unless data.nil?
            props[:enable_javascript] = enable_javascript unless enable_javascript.nil?
            props[:expand] = expand unless expand.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:method] = method unless method.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:url] = url unless url.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_page_ended] = on_page_ended unless on_page_ended.nil?
            props[:on_page_started] = on_page_started unless on_page_started.nil?
            props[:on_web_resource_error] = on_web_resource_error unless on_web_resource_error.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
