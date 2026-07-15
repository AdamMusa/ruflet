# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class PageControl < Ruflet::Control
          TYPE = "page".freeze
          WIRE = "Page".freeze

          KEYWORDS = [:adaptive, :badge, :client_ip, :client_user_agent, :col, :dark_theme, :data, :debug, :disabled, :enable_screenshots, :expand, :expand_loose, :fonts, :height, :key, :locale_configuration, :media, :multi_view, :multi_views, :opacity, :platform, :platform_brightness, :pwa, :pyodide, :route, :rtl, :sess, :show_semantics_debugger, :test, :theme, :theme_mode, :title, :tooltip, :views, :visible, :wasm, :web, :width, :window, :on_app_lifecycle_state_change, :on_close, :on_connect, :on_disconnect, :on_error, :on_keyboard_event, :on_locale_change, :on_login, :on_logout, :on_media_change, :on_multi_view_add, :on_multi_view_remove, :on_platform_brightness_change, :on_resize, :on_route_change, :on_view_pop].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end
        end
      end
    end
  end
end
