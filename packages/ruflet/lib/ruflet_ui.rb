# frozen_string_literal: true

require "ruflet_protocol"
require_relative "ruflet_ui/ruflet/colors"
require_relative "ruflet_ui/ruflet/icon_data"
require_relative "ruflet_ui/ruflet/icons/material/material_icons"
require_relative "ruflet_ui/ruflet/icons/cupertino/cupertino_icons"
require_relative "ruflet_ui/ruflet/types/text_style"
require_relative "ruflet_ui/ruflet/types/geometry"
require_relative "ruflet_ui/ruflet/control"
require_relative "ruflet_ui/ruflet/ui/control_registry"
require_relative "ruflet_ui/ruflet/ui/widget_builder"
require_relative "ruflet_ui/ruflet/ui/shared_control_forwarders"
require_relative "ruflet_ui/ruflet/event"
require_relative "ruflet_ui/ruflet/page"
require_relative "ruflet_ui/ruflet/app"
require_relative "ruflet_ui/ruflet/dsl"

module Ruflet
  TextStyle = UI::Types::TextStyle
  StrutStyle = UI::Types::StrutStyle
  TextOverflow = UI::Types::TextOverflow
  TextBaseline = UI::Types::TextBaseline
  TextThemeStyle = UI::Types::TextThemeStyle
  TextDecoration = UI::Types::TextDecoration
  TextDecorationStyle = UI::Types::TextDecorationStyle
  Offset = UI::Types::Offset
  Duration = UI::Types::Duration

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
    class IconGroup
      def initialize(icon_module)
        @icon_module = icon_module
      end

      def [](name)
        @icon_module[name]
      end

      def names
        @icon_module.names
      end

      def all
        @icon_module.all
      end

      def random
        @icon_module.random
      end

      def const_missing(name)
        return @icon_module.const_get(name) if @icon_module.const_defined?(name, false)

        super
      end
    end

    class << self
      def material
        @material ||= IconGroup.new(Ruflet::MaterialIcons)
      end

      def cupertino
        @cupertino ||= IconGroup.new(Ruflet::CupertinoIcons)
      end

      def const_missing(name)
        if Ruflet::MaterialIcons.const_defined?(name, false)
          return Ruflet::MaterialIcons.const_get(name)
        end

        if Ruflet::CupertinoIcons.const_defined?(name, false)
          return Ruflet::CupertinoIcons.const_get(name)
        end

        super
      end

      def [](name)
        key = name.to_s.upcase.to_sym
        return Ruflet::MaterialIcons.const_get(key) if Ruflet::MaterialIcons.const_defined?(key, false)
        return Ruflet::CupertinoIcons.const_get(key) if Ruflet::CupertinoIcons.const_defined?(key, false)

        Ruflet::IconData.new(name.to_s)
      end
    end
  end

  class << self
    include UI::SharedControlForwarders

    def app(host: nil, port: nil, &block)
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

      def app(**opts, &block) = Ruflet.app(**opts, &block)
      def page(**props, &block) = Ruflet::DSL.page(**props, &block)

      private

      def control_delegate
        Ruflet::DSL
      end
    end
  end
end

module Kernel
  include Ruflet::UI::SharedControlForwarders

  private

  def app(**opts, &block) = Ruflet::DSL.app(**opts, &block)
  def page(**props, &block) = Ruflet::DSL.page(**props, &block)

  def control_delegate
    Ruflet::DSL
  end

  if Ruflet::UI::SharedControlForwarders.respond_to?(:instance_methods)
    private(*Ruflet::UI::SharedControlForwarders.instance_methods(false))
  end
end
