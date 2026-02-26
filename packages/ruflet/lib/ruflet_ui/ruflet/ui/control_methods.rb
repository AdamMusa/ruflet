# frozen_string_literal: true

require_relative "material_control_methods"
require_relative "cupertino_control_methods"

module Ruflet
  module UI
    module ControlMethods
      include MaterialControlMethods
      include CupertinoControlMethods

      def control(type, **props, &block) = build_widget(type, **props, &block)
      def widget(type, **props, &block) = build_widget(type, **props, &block)
    end
  end
end
