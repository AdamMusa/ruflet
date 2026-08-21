# frozen_string_literal: true

module Ruflet
  module UI
    module ControlRegistry
      require_relative "material_control_registry"
      require_relative "cupertino_control_registry"
      require_relative "controls/ruflet_controls"
      require_relative "services/ruflet_services"
      # Controls whose Ruby name and wire name differ on purpose. The client
      # Native Ruflet clients use RufletApp as the canonical wire type while
      # the Ruby API remains ruflet_app.
      #
      # RufletAppControl::WIRE already says this, but that is only read when the
      # control resolves to its own class. Serialization otherwise derives the
      # wire name from the type and must still send the canonical RufletApp.
      # Map it here so both paths agree. to_patch also looks the type up with
      # underscores removed, so register that spelling too.
      SHARED_TYPE_MAP = {
        "ruflet_app" => "RufletApp",
        "rufletapp" => "RufletApp"
      }.freeze

      TYPE_MAP = MaterialControlRegistry::TYPE_MAP
                 .merge(CupertinoControlRegistry::TYPE_MAP)
                 .merge(SHARED_TYPE_MAP)
                 .freeze
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
