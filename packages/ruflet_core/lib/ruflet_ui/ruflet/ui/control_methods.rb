# frozen_string_literal: true

require_relative "material_control_methods"
require_relative "platform_control_methods"
require_relative "cupertino_control_methods"

module Ruflet
  module UI
    module ControlMethods
      include MaterialControlMethods
      include PlatformControlMethods
      # Compatibility aliases only. They emit the same canonical wire types as
      # the methods above and never select the visual renderer.
      include CupertinoControlMethods

      def control(type, **props, &block) = build_widget(type, **props, &block)
      def widget(type, **props, &block) = build_widget(type, **props, &block)
      def service(type, **props, &block) = build_service(type, **props, &block)
    end
  end
end
