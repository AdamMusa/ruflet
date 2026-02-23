# frozen_string_literal: true

module RubyNative
  module UI
    module ControlRegistry
      require_relative "material_control_registry"
      require_relative "cupertino_control_registry"

      TYPE_MAP = MaterialControlRegistry::TYPE_MAP.merge(CupertinoControlRegistry::TYPE_MAP).freeze
      EVENT_PROPS = MaterialControlRegistry::EVENT_PROPS.merge(CupertinoControlRegistry::EVENT_PROPS).freeze
    end
  end
end
