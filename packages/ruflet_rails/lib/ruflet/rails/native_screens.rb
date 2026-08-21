# frozen_string_literal: true

module Ruflet
  module Rails
    # Screens without route declarations.
    #
    # A native app has one public route, the WebSocket. The screens behind it
    # are not endpoints anybody dials — they are reached only from inside a
    # session — so declaring a Rails route per screen adds a routing table that
    # nothing outside the app is allowed to use. This resolves a screen path to
    # a controller action by convention instead:
    #
    #   /native                    -> NativeController#home   (or #index)
    #   /native/counter            -> NativeController#counter
    #   /native/counter/increment  -> NativeController#counter_increment
    #   /native/device_feature/camera -> NativeController#device_feature, params[:id]
    #
    # The last two show the rule for extra segments: they are first tried as
    # part of the action name, and otherwise become positional params. That is
    # what lets one convention cover both an action that happens to live under
    # another ("counter/increment") and a parameterised screen ("device/:id"),
    # which is the pair a per-screen routing table normally exists to express.
    module NativeScreens
      # Actions to try for the root of a feature folder, in order.
      INDEX_ACTIONS = %w[home index show].freeze

      module_function

      # "/native/counter/increment" -> ["native", ["counter", "increment"]]
      def split_path(path)
        segments = path.to_s.split("/").reject(&:empty?)
        [segments.first, segments[1..] || []]
      end

      def controller_for(scope)
        return nil if scope.to_s.empty?

        name = "#{camelize(scope)}Controller"
        klass = constantize(name)
        klass if klass.respond_to?(:action)
      end

      # Longest action name first, so "counter/increment" prefers
      # #counter_increment over #counter with a stray param.
      def resolve(path)
        scope, rest = split_path(path)
        controller = controller_for(scope)
        return nil unless controller

        rest.length.downto(1) do |take|
          action = rest.first(take).join("_")
          next unless action_on?(controller, action)

          return { controller: controller, action: action, params: rest.drop(take) }
        end

        return index_screen(controller) if rest.empty?

        # No action matched the segments, so treat the first as the action and
        # the rest as its params: /native/device/camera -> #device, id "camera".
        action = rest.first
        return nil unless action_on?(controller, action)

        { controller: controller, action: action, params: rest.drop(1) }
      end

      def index_screen(controller)
        action = INDEX_ACTIONS.find { |candidate| action_on?(controller, candidate) }
        return nil unless action

        { controller: controller, action: action, params: [] }
      end

      def action_on?(controller, action)
        return false if action.to_s.empty?
        return false unless controller.respond_to?(:action_methods)

        controller.action_methods.include?(action.to_s)
      end

      def camelize(value)
        value.to_s.split(/[_\-]/).map { |part| part.sub(/\A./, &:upcase) }.join
      end

      def constantize(name)
        Object.const_get(name)
      rescue NameError
        nil
      end
    end
  end
end
