# frozen_string_literal: true

require_relative "controls/ruflet_controls"
require_relative "services/ruflet_services"
require_relative "../control"

module Ruflet
  module UI
    module ControlFactory
      module_function

      CLASS_MAP =
        Controls::RufletControls::CLASS_MAP
          .merge(Services::RufletServices::CLASS_MAP)
          .freeze

      def build(type, id: nil, **props)
        normalized_type = type.to_s.downcase
        if ENV["RUFLET_DEBUG"] == "1" && normalized_type == "floatingactionbutton"
          Kernel.warn("[factory] type=#{normalized_type} id=#{id.inspect} props=#{props.inspect}")
        end
        klass = CLASS_MAP[normalized_type]
        if klass
          normalized_props = normalize_constructor_props(klass, props)
          if ENV["RUFLET_DEBUG"] == "1" && normalized_type == "floatingactionbutton"
            Kernel.warn("[factory] normalized_props=#{normalized_props.inspect}")
          end
          return klass.new(id: id, **normalized_props)
        end

        raise ArgumentError, "Unknown control type: #{normalized_type}"
      end

      def normalize_constructor_props(klass, props)
        keywords = constructor_keywords(klass)
        return props if keywords.empty?

        allowed = keywords.map(&:to_s)
        mapped = props.each_with_object({}) { |(k, v), out| out[k.to_sym] = v }
        if mapped.key?("value") && !allowed.include?("value") && allowed.include?("text") && !mapped.key?("text")
          mapped["text"] = mapped.delete("value")
        end
        if mapped.key?(:value) && !allowed.include?("value") && allowed.include?("text") && !mapped.key?(:text)
          mapped[:text] = mapped.delete(:value)
        end
        mapped
      end

      def constructor_keywords(klass)
        klass.instance_method(:initialize).parameters
             .select { |kind, _| kind == :key || kind == :keyreq }
             .map { |_, name| name }
             .reject { |name| name == :id }
      rescue StandardError
        []
      end
    end
  end
end
