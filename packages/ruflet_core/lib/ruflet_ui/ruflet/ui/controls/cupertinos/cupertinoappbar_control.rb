# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoAppBarControl < Ruflet::Control
          TYPE = "cupertinoappbar".freeze
          WIRE = "CupertinoAppBar".freeze

          def initialize(id: nil, automatic_background_visibility: nil, automatically_imply_leading: nil, automatically_imply_title: nil, badge: nil, bgcolor: nil, border: nil, brightness: nil, col: nil, data: nil, disabled: nil, enable_background_filter_blur: nil, expand: nil, expand_loose: nil, key: nil, large: nil, leading: nil, opacity: nil, padding: nil, previous_page_title: nil, rtl: nil, title: nil, tooltip: nil, trailing: nil, transition_between_routes: nil, visible: nil)
            props = {}
            props[:automatic_background_visibility] = automatic_background_visibility unless automatic_background_visibility.nil?
            props[:automatically_imply_leading] = automatically_imply_leading unless automatically_imply_leading.nil?
            props[:automatically_imply_title] = automatically_imply_title unless automatically_imply_title.nil?
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:border] = border unless border.nil?
            props[:brightness] = brightness unless brightness.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:enable_background_filter_blur] = enable_background_filter_blur unless enable_background_filter_blur.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:key] = key unless key.nil?
            props[:large] = large unless large.nil?
            props[:leading] = leading unless leading.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:previous_page_title] = previous_page_title unless previous_page_title.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:title] = title unless title.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:trailing] = trailing unless trailing.nil?
            props[:transition_between_routes] = transition_between_routes unless transition_between_routes.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
