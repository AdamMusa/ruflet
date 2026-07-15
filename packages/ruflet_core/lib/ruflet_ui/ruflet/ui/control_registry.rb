# frozen_string_literal: true

module Ruflet
  module UI
    module ControlRegistry
      require_relative "material_control_registry"
      require_relative "cupertino_control_registry"
      require_relative "controls/ruflet_controls"
      require_relative "services/ruflet_services"
      TYPE_MAP = MaterialControlRegistry::TYPE_MAP.merge(CupertinoControlRegistry::TYPE_MAP).freeze
      SCHEMA_EVENT_PROPS =
        Controls::RufletControls::CLASS_MAP
          .merge(Services::RufletServices::CLASS_MAP)
          .values
          .uniq
          .each_with_object({}) do |schema, events|
            keywords =
              if schema.const_defined?(:KEYWORDS)
                schema::KEYWORDS
              else
                schema.instance_method(:initialize).parameters
                      .select { |kind, _| kind == :key || kind == :keyreq }
                      .map { |_, name| name }
              end
            keywords
              .select { |name| name.to_s.start_with?("on_") }
              .reject { |name| name.to_s.end_with?("_hint_text") }
              .each do |name|
              normalized = name.to_s[3..-1]
              events[:"on_#{normalized}"] = normalized
            end
          end
          .freeze
      EVENT_PROPS =
        MaterialControlRegistry::EVENT_PROPS
          .merge(CupertinoControlRegistry::EVENT_PROPS)
          .merge(SCHEMA_EVENT_PROPS)
          .freeze
    end
  end
end
