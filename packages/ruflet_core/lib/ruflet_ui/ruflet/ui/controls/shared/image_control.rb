# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ImageControl < Ruflet::Control
          TYPE = "image".freeze
          WIRE = "Image".freeze

          def initialize(id: nil, anti_alias: nil, border_radius: nil, cache_height: nil, cache_width: nil, color: nil, color_blend_mode: nil, data: nil, error_content: nil, exclude_from_semantics: nil, fade_in_animation: nil, filter_quality: nil, fit: nil, gapless_playback: nil, height: nil, key: nil, paint: nil, placeholder_fade_out_animation: nil, placeholder_fit: nil, placeholder_src: nil, repeat: nil, semantics_label: nil, src: nil, src_base64: nil, width: nil, x: nil, y: nil)
            props = {}
            props[:anti_alias] = anti_alias unless anti_alias.nil?
            props[:border_radius] = border_radius unless border_radius.nil?
            props[:cache_height] = cache_height unless cache_height.nil?
            props[:cache_width] = cache_width unless cache_width.nil?
            props[:color] = color unless color.nil?
            props[:color_blend_mode] = color_blend_mode unless color_blend_mode.nil?
            props[:data] = data unless data.nil?
            props[:error_content] = error_content unless error_content.nil?
            props[:exclude_from_semantics] = exclude_from_semantics unless exclude_from_semantics.nil?
            props[:fade_in_animation] = fade_in_animation unless fade_in_animation.nil?
            props[:filter_quality] = filter_quality unless filter_quality.nil?
            props[:fit] = fit unless fit.nil?
            props[:gapless_playback] = gapless_playback unless gapless_playback.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:paint] = paint unless paint.nil?
            props[:placeholder_fade_out_animation] = placeholder_fade_out_animation unless placeholder_fade_out_animation.nil?
            props[:placeholder_fit] = placeholder_fit unless placeholder_fit.nil?
            props[:placeholder_src] = placeholder_src unless placeholder_src.nil?
            props[:repeat] = repeat unless repeat.nil?
            props[:semantics_label] = semantics_label unless semantics_label.nil?
            props[:src] = src unless src.nil?
            props[:src_base64] = src_base64 unless src_base64.nil?
            props[:width] = width unless width.nil?
            props[:x] = x unless x.nil?
            props[:y] = y unless y.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
