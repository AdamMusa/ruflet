# frozen_string_literal: true

require_relative "material_control_factory"
require_relative "cupertino_control_factory"

module Ruflet
  module UI
    module ControlFactory
      module_function

      CLASS_MAP = MaterialControlFactory::CLASS_MAP.merge(CupertinoControlFactory::CLASS_MAP).freeze

      def build(type, id: nil, **props)
        normalized_type = type.to_s.downcase
        klass = CLASS_MAP[normalized_type]
        raise ArgumentError, "Unsupported control type: #{normalized_type}" unless klass

        klass.new(id: id, **props)
      end
    end
  end
end
