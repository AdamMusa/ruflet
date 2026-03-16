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
            schema.instance_method(:initialize).parameters
              .select { |kind, name| (kind == :key || kind == :keyreq) && name.to_s.start_with?("on_") }
              .each do |_, name|
              event_name = name.to_s.sub(/\Aon_/, "")
              normalized = event_name.to_s.sub(/\Aon_/, "")
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
