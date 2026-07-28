# frozen_string_literal: true

require "ruflet_protocol"
require_relative "ruflet_ui/ruflet/colors"
require_relative "ruflet_ui/ruflet/icon_data"
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
require_relative "ruflet_ui/ruflet/extensions"
require_relative "ruflet_ui/ruflet/extensions/qrcode_scanner"

module Ruflet
  # Icon tables are large (the material set alone parses a ~234KB map and
  # defines thousands of constants) but the common `icon("home")` path passes
  # the name straight through — nothing in the runtime touches these modules
  # unless an app references a constant like `Ruflet::Icons::HOME`. Autoload
  # them so boot (and every full restart) skips that cost until first use.
  #
  # CRuby only: under the embedded mruby VM the framework is concatenated into
  # one blob with no filesystem require, so these modules are already defined
  # there and the guard keeps the autoload calls out of that path entirely.
  if RUBY_ENGINE != "mruby"
    icons_root = File.expand_path("ruflet_ui/ruflet/icons", __dir__)
    autoload :MaterialIcons, File.join(icons_root, "material/material_icons")
    autoload :CupertinoIcons, File.join(icons_root, "cupertino/cupertino_icons")
  end

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

  # This is Kernel, so it sees every missing method in the process, including
  # ones Ruby itself calls speculatively and expects to raise. Fabricating a
  # control for those hands internals an object of the wrong type — a
  # Process::Waiter receiving one fails with "wrong argument type
  # Ruflet::Control (expected Process::Status)".
  #
  # Only build a control for a name the framework actually knows, or for calls
  # written at the top level of a script, where an unregistered extension
  # helper is still expected to work.
  def method_missing(name, *args, **props, &block)
    return super if name.to_s.end_with?("=") || (args.empty? && props.empty? && !block)
    unless Ruflet::UI::ControlFactory.known_control?(name) || Ruflet::UI::ControlFactory.dsl_receiver?(self)
      return super
    end

    forwarded = props.dup
    forwarded[:value] = args.shift unless args.empty?
    return super unless args.empty?

    Ruflet::DSL.control(name.to_s, **forwarded, &block)
  end

  if Ruflet::UI::SharedControlForwarders.respond_to?(:instance_methods)
    private(*Ruflet::UI::SharedControlForwarders.instance_methods(false))
  end
end
