# frozen_string_literal: true

module Ruflet
  # Registry used by Ruflet extension gems to add typed Ruby controls and
  # describe the matching Flet Flutter package. Registering a control makes its
  # helpers available in the bare DSL, Ruflet::DSL, Ruflet, Ruflet::UI, and
  # WidgetBuilder without editing Ruflet's generated control method tables.
  module Extensions
    Registration = Struct.new(
      :name,
      :control_class,
      :helpers,
      :flutter,
      keyword_init: true
    )

    @registrations = {}

    class << self
      def register_control(name, control_class:, helpers: nil, flutter: nil)
        key = normalize_name(name)
        helper_names = Array(helpers || key).map { |helper| normalize_name(helper) }.uniq.freeze
        registration = Registration.new(
          name: key,
          control_class: control_class,
          helpers: helper_names,
          flutter: normalize_flutter_metadata(flutter)
        ).freeze

        existing = @registrations[key]
        if existing && existing != registration
          raise ArgumentError, "Ruflet extension `#{key}` is already registered"
        end

        helper_names.each do |helper|
          UI::ControlFactory.register_extension(helper, control_class)
          define_control_helper(helper)
        end
        @registrations[key] = registration
      end

      def [](name)
        @registrations[normalize_name(name)]
      end

      def each(&block)
        return enum_for(:each) unless block

        @registrations.values.each(&block)
      end

      def registered?(name)
        @registrations.key?(normalize_name(name))
      end

      private

      def normalize_name(value)
        name = value.to_s.strip.downcase.tr("-", "_")
        raise ArgumentError, "Extension name cannot be empty" if name.empty?
        raise ArgumentError, "Invalid extension name `#{value}`" unless name.match?(/\A[a-z][a-z0-9_]*\z/)

        name
      end

      def normalize_flutter_metadata(metadata)
        return nil if metadata.nil?

        values = metadata.transform_keys(&:to_sym)
        package = values.fetch(:package).to_s
        import = values.fetch(:import, "package:#{package}/#{package}.dart").to_s
        alias_name = values.fetch(:alias, package).to_s
        constructor = values.fetch(:constructor, "Extension").to_s
        {
          package: package,
          import: import,
          alias: alias_name,
          constructor: constructor
        }.freeze
      end

      def define_control_helper(helper)
        type = helper

        UI::ControlMethods.send(:define_method, helper) do |**props, &block|
          control(type, **props, &block)
        end

        UI::SharedControlForwarders.send(:define_method, helper) do |**props, &block|
          control_delegate.public_send(type, **props, &block)
        end

        DSL.define_singleton_method(helper) do |**props, &block|
          _pending_app.public_send(type, **props, &block)
        end

        Kernel.send(:private, helper) if Kernel.method_defined?(helper)
      end
    end
  end
end
