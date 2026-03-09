# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class BasePageControl < Ruflet::Control
          TYPE = "basepage".freeze
          WIRE = "BasePage".freeze

          def initialize(id: nil, adaptive: nil, badge: nil, col: nil, dark_theme: nil, data: nil, disabled: nil, enable_screenshots: nil, expand: nil, expand_loose: nil, height: nil, key: nil, locale_configuration: nil, media: nil, opacity: nil, rtl: nil, show_semantics_debugger: nil, theme: nil, theme_mode: nil, title: nil, tooltip: nil, views: nil, visible: nil, width: nil, on_media_change: nil, on_resize: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:dark_theme] = dark_theme unless dark_theme.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:enable_screenshots] = enable_screenshots unless enable_screenshots.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:locale_configuration] = locale_configuration unless locale_configuration.nil?
            props[:media] = media unless media.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:show_semantics_debugger] = show_semantics_debugger unless show_semantics_debugger.nil?
            props[:theme] = theme unless theme.nil?
            props[:theme_mode] = theme_mode unless theme_mode.nil?
            props[:title] = title unless title.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:views] = views unless views.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_media_change] = on_media_change unless on_media_change.nil?
            props[:on_resize] = on_resize unless on_resize.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
