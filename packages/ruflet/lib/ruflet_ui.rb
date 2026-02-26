# frozen_string_literal: true

require "ruflet_protocol"
require_relative "ruflet_ui/ruflet/colors"
require_relative "ruflet_ui/ruflet/icon_data"
require_relative "ruflet_ui/ruflet/icons/material_icons"
require_relative "ruflet_ui/ruflet/icons/cupertino/cupertino_icons"
require_relative "ruflet_ui/ruflet/control"
require_relative "ruflet_ui/ruflet/ui/widget_builder"
require_relative "ruflet_ui/ruflet/ui/shared_control_forwarders"
require_relative "ruflet_ui/ruflet/event"
require_relative "ruflet_ui/ruflet/page"
require_relative "ruflet_ui/ruflet/app"
require_relative "ruflet_ui/ruflet/dsl"

module Ruflet
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
    class << self
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

  private(*Ruflet::UI::SharedControlForwarders.instance_methods(false))
end
