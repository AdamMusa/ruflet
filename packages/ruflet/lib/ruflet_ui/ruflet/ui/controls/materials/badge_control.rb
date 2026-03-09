# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class BadgeControl < Ruflet::Control
          TYPE = "badge".freeze
          WIRE = "Badge".freeze

          def initialize(id: nil, alignment: nil, bgcolor: nil, data: nil, key: nil, label: nil, label_visible: nil, large_size: nil, offset: nil, padding: nil, small_size: nil, text_color: nil, text_style: nil)
            props = {}
            props[:alignment] = alignment unless alignment.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:label_visible] = label_visible unless label_visible.nil?
            props[:large_size] = large_size unless large_size.nil?
            props[:offset] = offset unless offset.nil?
            props[:padding] = padding unless padding.nil?
            props[:small_size] = small_size unless small_size.nil?
            props[:text_color] = text_color unless text_color.nil?
            props[:text_style] = text_style unless text_style.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
