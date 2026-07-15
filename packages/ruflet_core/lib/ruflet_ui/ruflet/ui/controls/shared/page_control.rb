# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class PageControl < Ruflet::Control
          TYPE = "page".freeze
          WIRE = "Page".freeze

          def initialize(id: nil, adaptive: nil, badge: nil, client_ip: nil, client_user_agent: nil, col: nil, dark_theme: nil, data: nil, debug: nil, disabled: nil, enable_screenshots: nil, expand: nil, expand_loose: nil, fonts: nil, height: nil, key: nil, locale_configuration: nil, media: nil, multi_view: nil, multi_views: nil, opacity: nil, platform: nil, platform_brightness: nil, pwa: nil, pyodide: nil, route: nil, rtl: nil, sess: nil, show_semantics_debugger: nil, test: nil, theme: nil, theme_mode: nil, title: nil, tooltip: nil, views: nil, visible: nil, wasm: nil, web: nil, width: nil, window: nil, on_app_lifecycle_state_change: nil, on_close: nil, on_connect: nil, on_disconnect: nil, on_error: nil, on_keyboard_event: nil, on_locale_change: nil, on_login: nil, on_logout: nil, on_media_change: nil, on_multi_view_add: nil, on_multi_view_remove: nil, on_platform_brightness_change: nil, on_resize: nil, on_route_change: nil, on_view_pop: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:client_ip] = client_ip unless client_ip.nil?
            props[:client_user_agent] = client_user_agent unless client_user_agent.nil?
            props[:col] = col unless col.nil?
            props[:dark_theme] = dark_theme unless dark_theme.nil?
            props[:data] = data unless data.nil?
            props[:debug] = debug unless debug.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:enable_screenshots] = enable_screenshots unless enable_screenshots.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:fonts] = fonts unless fonts.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:locale_configuration] = locale_configuration unless locale_configuration.nil?
            props[:media] = media unless media.nil?
            props[:multi_view] = multi_view unless multi_view.nil?
            props[:multi_views] = multi_views unless multi_views.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:platform] = platform unless platform.nil?
            props[:platform_brightness] = platform_brightness unless platform_brightness.nil?
            props[:pwa] = pwa unless pwa.nil?
            props[:pyodide] = pyodide unless pyodide.nil?
            props[:route] = route unless route.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:sess] = sess unless sess.nil?
            props[:show_semantics_debugger] = show_semantics_debugger unless show_semantics_debugger.nil?
            props[:test] = test unless test.nil?
            props[:theme] = theme unless theme.nil?
            props[:theme_mode] = theme_mode unless theme_mode.nil?
            props[:title] = title unless title.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:views] = views unless views.nil?
            props[:visible] = visible unless visible.nil?
            props[:wasm] = wasm unless wasm.nil?
            props[:web] = web unless web.nil?
            props[:width] = width unless width.nil?
            props[:window] = window unless window.nil?
            props[:on_app_lifecycle_state_change] = on_app_lifecycle_state_change unless on_app_lifecycle_state_change.nil?
            props[:on_close] = on_close unless on_close.nil?
            props[:on_connect] = on_connect unless on_connect.nil?
            props[:on_disconnect] = on_disconnect unless on_disconnect.nil?
            props[:on_error] = on_error unless on_error.nil?
            props[:on_keyboard_event] = on_keyboard_event unless on_keyboard_event.nil?
            props[:on_locale_change] = on_locale_change unless on_locale_change.nil?
            props[:on_login] = on_login unless on_login.nil?
            props[:on_logout] = on_logout unless on_logout.nil?
            props[:on_media_change] = on_media_change unless on_media_change.nil?
            props[:on_multi_view_add] = on_multi_view_add unless on_multi_view_add.nil?
            props[:on_multi_view_remove] = on_multi_view_remove unless on_multi_view_remove.nil?
            props[:on_platform_brightness_change] = on_platform_brightness_change unless on_platform_brightness_change.nil?
            props[:on_resize] = on_resize unless on_resize.nil?
            props[:on_route_change] = on_route_change unless on_route_change.nil?
            props[:on_view_pop] = on_view_pop unless on_view_pop.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
