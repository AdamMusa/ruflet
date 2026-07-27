# frozen_string_literal: true

require_relative "controls/ruflet_controls"
require_relative "services/ruflet_services"
require_relative "../control"

module Ruflet
  module UI
    module ControlFactory
      module_function

      CLASS_MAP =
        Services::RufletServices::CLASS_MAP
          .merge(Controls::RufletControls::CLASS_MAP)
          .freeze
      EXTENSION_CLASS_MAP = {}
      CONSTRUCTOR_KEYWORDS_CACHE = {}

      COMMON_ATTRIBUTES = %i[flip ref transform].freeze
      ATTRIBUTE_OVERRIDES = {
        "expansionpanellist" => %i[auto_scroll on_scroll scroll scroll_interval],
        "ruflet_app" => %i[assets_dir on_python_output],
        "rufletapp" => %i[assets_dir on_python_output],
        "image" => %i[
          align animate_align animate_margin animate_offset animate_opacity animate_position
          animate_rotation animate_scale animate_size aspect_ratio badge bottom col disabled
          expand expand_loose left margin offset on_animation_end on_size_change opacity right
          rotate rtl scale size_change_interval tooltip top visible
        ],
        "navigationrail" => %i[pin_leading_to_top pin_trailing_to_bottom scrollable],
        "responsiverow" => %i[auto_scroll on_scroll scroll scroll_interval],
        "text" => %i[
          align animate_align animate_margin animate_offset animate_opacity animate_position
          animate_rotation animate_scale animate_size aspect_ratio badge bottom col disabled
          expand expand_loose height left margin offset on_animation_end on_size_change opacity
          right rtl scale size_change_interval tooltip top visible width
        ]
      }.freeze

      def build(type, id: nil, **props)
        normalized_type = type.to_s.downcase
        if ENV["RUFLET_DEBUG"] == "1" && normalized_type == "floatingactionbutton"
          Kernel.warn("[factory] type=#{normalized_type} id=#{id.inspect} props=#{props.inspect}")
        end
        klass = EXTENSION_CLASS_MAP[normalized_type] || CLASS_MAP[normalized_type]
        if klass
          normalized_props, supplemental_props = normalize_constructor_props(klass, normalized_type, props)
          if ENV["RUFLET_DEBUG"] == "1" && normalized_type == "floatingactionbutton"
            Kernel.warn("[factory] normalized_props=#{normalized_props.inspect}")
          end
          control = klass.new(id: id, **normalized_props)
          supplemental_props.each do |key, value|
            if key.to_s.start_with?("on_") && value.respond_to?(:call)
              control.attach_handler(key.to_s.delete_prefix("on_"), value)
              next
            end
            next if key == :ref

            control.props[key.to_s] = normalize_common_value(value)
          end
          return control
        end

        Control.new(type: normalized_type, id: id, **props)
      end

      def normalize_constructor_props(klass, type, props)
        keywords = constructor_keywords(klass)
        return [props, {}] if keywords.empty? && ATTRIBUTE_OVERRIDES[type].nil?

        allowed = keywords.map(&:to_s)
        mapped = props.each_with_object({}) { |(k, v), out| out[k.to_sym] = v }
        if mapped.key?("value") && !allowed.include?("value") && allowed.include?("text") && !mapped.key?("text")
          mapped["text"] = mapped.delete("value")
        end
        if mapped.key?(:value) && !allowed.include?("value") && allowed.include?("text") && !mapped.key?(:text)
          mapped[:text] = mapped.delete(:value)
        end
        supplemental_names = COMMON_ATTRIBUTES + ATTRIBUTE_OVERRIDES.fetch(type, [])
        supplemental = mapped.slice(*supplemental_names)
        [mapped.reject { |key, _| supplemental_names.include?(key) }, supplemental]
      end

      def constructor_keywords(klass)
        return CONSTRUCTOR_KEYWORDS_CACHE[klass] if CONSTRUCTOR_KEYWORDS_CACHE.key?(klass)

        keywords = if klass.const_defined?(:KEYWORDS)
          klass::KEYWORDS
        else
          klass.instance_method(:initialize).parameters
               .select { |kind, _| kind == :key || kind == :keyreq }
               .map { |_, name| name }
               .reject { |name| name == :id }
        end

        CONSTRUCTOR_KEYWORDS_CACHE[klass] = keywords.freeze
      rescue StandardError
        []
      end

      def register_extension(type, klass)
        key = type.to_s.downcase
        raise ArgumentError, "Extension control type cannot be empty" if key.empty?
        raise ArgumentError, "Extension control must inherit Ruflet::Control" unless klass <= Ruflet::Control

        existing = EXTENSION_CLASS_MAP[key]
        if existing && existing != klass
          raise ArgumentError, "Extension control `#{key}` is already registered by #{existing}"
        end

        EXTENSION_CLASS_MAP[key] = klass
        CONSTRUCTOR_KEYWORDS_CACHE.delete(klass)
        klass
      end

      def normalize_common_value(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested), result|
            result[key.to_s] = normalize_common_value(nested)
          end
        when Array
          value.map { |nested| normalize_common_value(nested) }
        when Symbol
          value.to_s
        else
          value
        end
      end
    end
  end
end
