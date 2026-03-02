# frozen_string_literal: true

require_relative "material_control_factory"
require_relative "cupertino_control_factory"
require_relative "../control"

module Ruflet
  module UI
    module ControlFactory
      module_function

      CLASS_MAP = MaterialControlFactory::CLASS_MAP.merge(CupertinoControlFactory::CLASS_MAP).freeze

      def build(type, id: nil, **props)
        normalized_type = type.to_s.downcase
        klass = CLASS_MAP[normalized_type]
        return klass.new(id: id, **props) if klass

        Ruflet::Control.new(type: normalized_type, id: id, **props)
      end
    end
  end
end
