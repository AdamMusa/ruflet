# frozen_string_literal: true

require "ruby_native_protocol"
require_relative "ruby_native/colors"
require_relative "ruby_native/icon_data"
require_relative "ruby_native/icons/material_icons"
require_relative "ruby_native/icons/cupertino/cupertino_icons"
require_relative "ruby_native/control"
require_relative "ruby_native/ui/widget_builder"
require_relative "ruby_native/ui/shared_control_forwarders"
require_relative "ruby_native/event"
require_relative "ruby_native/page"
require_relative "ruby_native/app"
require_relative "ruby_native/dsl"

module RubyNative
  module MainAxisAlignment
    CENTER = "center"
    START = "start"
    FINISH = "end"
    SPACE_BETWEEN = "spaceBetween"
    SPACE_AROUND = "spaceAround"
    SPACE_EVENLY = "spaceEvenly"
  end

  module CrossAxisAlignment
    CENTER = "center"
    START = "start"
    FINISH = "end"
    STRETCH = "stretch"
  end

  module TextAlign
    LEFT = "left"
    RIGHT = "right"
    CENTER = "center"
    JUSTIFY = "justify"
    START = "start"
    FINISH = "end"
  end

  module Icons
    REMOVE = MaterialIcons::REMOVE
    ADD = MaterialIcons::ADD

    class << self
      def const_missing(name)
        if RubyNative::MaterialIcons.const_defined?(name, false)
          return RubyNative::MaterialIcons.const_get(name)
        end

        if RubyNative::CupertinoIcons.const_defined?(name, false)
          return RubyNative::CupertinoIcons.const_get(name)
        end

        super
      end

      def [](name)
        key = name.to_s.upcase.to_sym
        return RubyNative::MaterialIcons.const_get(key) if RubyNative::MaterialIcons.const_defined?(key, false)
        return RubyNative::CupertinoIcons.const_get(key) if RubyNative::CupertinoIcons.const_defined?(key, false)

        RubyNative::IconData.new(name.to_s)
      end
    end
  end

  class << self
    include UI::SharedControlForwarders

    def app(host: "0.0.0.0", port: 8550, &block)
      DSL.app(host: host, port: port, &block)
    end

    private

    def control_delegate
      WidgetBuilder.new
    end
  end

  module UI
    class << self
      include SharedControlForwarders

      def app(**opts, &block) = RubyNative.app(**opts, &block)
      def page(**props, &block) = RubyNative::DSL.page(**props, &block)

      private

      def control_delegate
        RubyNative::DSL
      end
    end
  end
end

module Kernel
  include RubyNative::UI::SharedControlForwarders

  private

  def app(**opts, &block) = RubyNative::DSL.app(**opts, &block)
  def page(**props, &block) = RubyNative::DSL.page(**props, &block)

  def control_delegate
    RubyNative::DSL
  end

  private(*RubyNative::UI::SharedControlForwarders.instance_methods(false))
end
