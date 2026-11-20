# frozen_string_literal: true

# Contract checks for every control and service the factory can build.
#
# A spec (see test/support/control_contracts/*.rb) states what a reader of the
# wire needs to know about one control class: its wire type, every name it is
# registered under, the props it cannot be built without, and any prop or
# event that is sent under a different key. The props and events themselves
# come from ControlFactory.constructor_keywords: the class's KEYWORDS, or its
# constructor's keyword parameters when it has no KEYWORDS constant. So a
# keyword added to a control is tested without touching its spec, and a
# control added to the factory fails ControlContractCoverageTest until it has
# a spec.
#
# An open-schema class has no constructor keywords and passes any prop and
# on_* handler through (Video, WebView, Map, the ads, charts and pickers). Its
# spec lists, under props: and events:, what the engine's renderer for it
# reads. Every open-schema class is also checked with one prop and one event
# that no renderer reads (OPEN_SCHEMA_PROBE_PROP, OPEN_SCHEMA_PROBE_EVENT), so
# a class that drops what it is given fails either way.
#
# Wire keys come from Ruby's constructor keywords, not from Flet's Dart
# names: the renderer reads the keys Ruby sends. Only an open-schema class,
# which has no keywords to read them from, takes its names from the engine.
module ControlContract
  # A sample value for one prop: what the test passes in, and what the patch
  # must then carry under the prop's wire key.
  Sample = Struct.new(:input, :expected)

  Spec = Struct.new(
    :family, :type, :wire, :aliases, :base, :samples, :wire_keys,
    :client_events, :helper, :helper_props, :props, :events,
    keyword_init: true
  )

  # A child control for props a control cannot be built without.
  TEXT = -> { Ruflet.text("x") }
  TWO_TEXTS = -> { [Ruflet.text("a"), Ruflet.text("b")] }

  # Valid values for the timing props every transition checks.
  TIMING_SAMPLES = { animating: true, curve: "ease_in_out", delay: 150, duration: 400, repeat: true, reverse: true }.freeze

  # What every open-schema class is checked with besides its spec's props:
  # and events:. No renderer reads them; the class must still send them.
  OPEN_SCHEMA_PROBE_PROP = :contract_open_schema_prop
  OPEN_SCHEMA_PROBE_EVENT = :on_contract_open_schema_event

  ICON_SAMPLE = "add"
  COLOR_SAMPLE = "#a1b2c3"

  @specs = {}

  class << self
    attr_reader :specs

    # Registers a family's specs. Each entry is `type => options`, where type
    # is the name the spec builds with and options are:
    #   wire:          the wire type (`_c`) every registered name must send
    #   aliases:       the other names the factory registers for the class
    #   base:          props the control cannot be built without
    #   samples:       prop => value, or prop => Sample, replacing the default
    #   wire_keys:     prop/event => the key the patch carries it under
    #   client_events: event => the event name the client sends for it
    #   helper:        the Ruflet.* helper that builds it, or false for none
    #   helper_props:  what to pass the helper, when not the base props
    #   props:         props to test besides the constructor keywords; for an
    #                  open-schema class, the ones its renderer reads
    #   events:        on_* events to test besides the constructor keywords;
    #                  likewise
    def define(family, entries)
      entries.each do |type, options|
        options = options.dup
        type = type.to_s
        spec = Spec.new(
          family: family,
          type: type,
          wire: options.delete(:wire) || raise(ArgumentError, "#{type}: wire: is required"),
          aliases: Array(options.delete(:aliases)).map(&:to_s),
          base: options.delete(:base) || {},
          samples: options.delete(:samples) || {},
          wire_keys: (options.delete(:wire_keys) || {}).transform_keys(&:to_sym),
          client_events: (options.delete(:client_events) || {}).transform_keys(&:to_sym),
          helper: options.key?(:helper) ? options.delete(:helper) : :default,
          helper_props: options.delete(:helper_props),
          props: Array(options.delete(:props)).map(&:to_sym),
          events: Array(options.delete(:events)).map(&:to_sym)
        )
        raise ArgumentError, "#{type}: unknown spec options #{options.keys}" unless options.empty?
        if (misplaced = spec.props.select { |name| event_keyword?(name) }).any?
          raise ArgumentError, "#{type}: #{misplaced} are events; list them under events:"
        end
        if (misplaced = spec.events.reject { |name| event_keyword?(name) }).any?
          raise ArgumentError, "#{type}: #{misplaced} are not on_* events; list them under props:"
        end
        if (repeated = (spec.props + spec.events).tally.select { |_name, count| count > 1 }.keys).any?
          raise ArgumentError, "#{type}: #{repeated} listed more than once"
        end
        raise ArgumentError, "#{type} is specified twice" if @specs.key?(type)

        @specs[type] = spec
      end
    end

    def family(name)
      @specs.values.select { |spec| spec.family == name }
    end

    # Every name the factory resolves, grouped by the class it builds: the
    # built-in controls and services, and the extensions Ruflet ships.
    def registered_names_by_class
      groups = Ruflet::UI::ControlFactory::CLASS_MAP.each_with_object({}) do |(name, klass), out|
        (out[klass] ||= []) << name
      end
      shipped_extensions.each do |registration|
        groups[registration.control_class] = registration.helpers.dup
      end
      groups
    end

    # Extension registrations whose control is defined in this gem's lib, as
    # opposed to ones a test or an application registered at runtime.
    def shipped_extensions
      lib = File.expand_path("../../lib", __dir__)
      Ruflet::Extensions.each.select do |registration|
        file = Object.const_source_location(registration.control_class.name)&.first
        file&.start_with?(lib)
      end
    end

    # The class the factory builds for a name, extensions included.
    def class_for(name)
      Ruflet::UI::ControlFactory::EXTENSION_CLASS_MAP[name] || Ruflet::UI::ControlFactory::CLASS_MAP[name]
    end

    # A class with no constructor keywords passes any prop through.
    def open_schema?(klass)
      Ruflet::UI::ControlFactory.constructor_keywords(klass).empty?
    end

    def service_class?(klass)
      Ruflet::UI::Services::RufletServices::CLASS_MAP.value?(klass)
    end

    def event_keyword?(name)
      name = name.to_s
      name.start_with?("on_") && !name.end_with?("_hint_text") && name != "on_label_color"
    end

    def icon_key?(name)
      name = name.to_s
      return false if name.start_with?("show_")

      name == "icon" || name.end_with?("_icon") || name == "leading" || name == "trailing"
    end

    def color_key?(name)
      name = name.to_s
      name == "color" || name.end_with?("bgcolor") || name.end_with?("_color")
    end

    def icon_codepoint
      Ruflet::MaterialIconLookup.codepoint_for(ICON_SAMPLE)
    end

    def client_action_sample
      action = Ruflet::ClientAction.new(:launch_url, url: "https://ruflet.dev")
      Sample.new(action, action.to_h)
    end
  end

  # Assertions the generated contract tests call.
  module Assertions
    private

    def contract_class(spec)
      ControlContract.class_for(spec.type) || raise(KeyError, "the factory builds nothing for #{spec.type}")
    end

    def contract_keywords(spec)
      Ruflet::UI::ControlFactory.constructor_keywords(contract_class(spec))
    end

    # The constructor keywords that are props, then the spec's props:, then
    # for an open-schema class the probe prop.
    def contract_props(spec)
      props = contract_keywords(spec).reject { |name| ControlContract.event_keyword?(name) }
      contract_names(spec, props, spec.props, ControlContract::OPEN_SCHEMA_PROBE_PROP)
    end

    # Likewise for the on_* events.
    def contract_events(spec)
      events = contract_keywords(spec).select { |name| ControlContract.event_keyword?(name) }
      contract_names(spec, events, spec.events, ControlContract::OPEN_SCHEMA_PROBE_EVENT)
    end

    def contract_names(spec, keywords, listed, probe)
      names = keywords.map(&:to_sym) + listed
      names << probe if ControlContract.open_schema?(contract_class(spec))
      names.uniq
    end

    def contract_base(spec)
      contract_values(spec.base)
    end

    def contract_values(props)
      props.transform_values { |value| value.is_a?(Proc) && value.arity.zero? ? value.call : value }
    end

    def build_contract_control(spec, as: spec.type, **props)
      Ruflet::UI::ControlFactory.build(as, **contract_base(spec).merge(props))
    end

    def contract_sample(spec, prop)
      value = spec.samples.fetch(prop) { default_contract_sample(prop) }
      value = value.call if value.is_a?(Proc) && value.arity.zero?
      return value if value.is_a?(ControlContract::Sample)

      ControlContract::Sample.new(value, expected_wire_value(value))
    end

    def default_contract_sample(prop)
      return ControlContract::Sample.new(ControlContract::ICON_SAMPLE, ControlContract.icon_codepoint) if ControlContract.icon_key?(prop)
      return ControlContract::Sample.new(ControlContract::COLOR_SAMPLE, ControlContract::COLOR_SAMPLE) if ControlContract.color_key?(prop)
      return ControlContract.client_action_sample if prop.to_s == "action"

      "sample:#{prop}"
    end

    def expected_wire_value(value)
      case value
      when Ruflet::Control then value.to_patch
      when Symbol then value.to_s
      when Array then value.map { |item| expected_wire_value(item) }
      when Hash then value.each_with_object({}) { |(key, item), out| out[key.to_s] = expected_wire_value(item) }
      else value
      end
    end

    def contract_wire_key(spec, keyword)
      spec.wire_keys.fetch(keyword.to_sym, keyword.to_s)
    end

    def contract_page(sent = [])
      Ruflet::Page.new(
        session_id: "contract",
        client_details: { "route" => "/" },
        sender: ->(action, payload) { sent << [action, payload] }
      )
    end

    def mount_contract_control(page, control)
      if ControlContract.service_class?(control.class)
        page.add_service(control)
      else
        page.add(control)
      end
      control
    end

    # The wire type, and that every registered name, the TYPE_MAP entry for
    # it and the Ruflet.* helper all agree on it.
    def assert_contract_wire_type(spec)
      klass = contract_class(spec)
      control = build_contract_control(spec)

      assert_instance_of klass, control
      assert_equal spec.wire, control.to_patch["_c"], "#{spec.type} wire type"
      assert_equal spec.wire, control.wire_type

      registered = ControlContract.registered_names_by_class.fetch(klass)
      assert_equal registered.sort, ([spec.type] + spec.aliases).sort,
                   "#{spec.type}: the spec's aliases must be every name the factory registers for #{klass}"

      spec.aliases.each do |name|
        aliased = build_contract_control(spec, as: name)
        assert_instance_of klass, aliased, "#{name} builds #{klass}"
        assert_equal spec.wire, aliased.to_patch["_c"], "#{name} wire type"
      end

      type_map = Ruflet::UI::ControlRegistry::TYPE_MAP
      registered.each do |name|
        next unless type_map.key?(name)

        assert_equal spec.wire, type_map.fetch(name), "TYPE_MAP[#{name.inspect}] must agree with #{klass}::WIRE"
        assert_equal spec.wire, Ruflet::Control.new(type: name).wire_type,
                     "an untyped Ruflet::Control of type #{name.inspect} sends the same wire type"
      end
    end

    def assert_contract_helper(spec)
      helper = spec.helper == :default ? spec.type : spec.helper
      return pass if helper == false

      assert Ruflet.respond_to?(helper), "Ruflet.#{helper} builds #{spec.type}"
      props = spec.helper_props ? contract_values(spec.helper_props) : contract_base(spec)
      control = Ruflet.public_send(helper, **props)
      assert_instance_of contract_class(spec), control
      assert_equal spec.wire, control.to_patch["_c"]
    end

    # Each prop (see contract_props), set on its own, reaches the patch under
    # its wire key.
    def assert_contract_props(spec)
      failures = contract_props(spec).filter_map do |prop|
        sample = contract_sample(spec, prop)
        key = contract_wire_key(spec, prop)
        begin
          patch = build_contract_control(spec, prop => sample.input).to_patch
        rescue StandardError => e
          next "#{prop}: #{e.class}: #{e.message}"
        end
        next if patch.key?(key) && patch[key] == sample.expected

        sent = patch.key?(key) ? patch[key].inspect : "nothing"
        "#{prop}: expected #{key.inspect} => #{sample.expected.inspect}, sent #{sent}"
      end

      assert_empty failures, "#{spec.type} props that do not serialize under their Ruby wire key"
    end

    # Each on_* event (see contract_events), given a handler, flags the event
    # on the wire and runs the handler when the client sends the event for the
    # mounted control.
    def assert_contract_events(spec)
      failures = contract_events(spec).filter_map do |event|
        name = event.to_s.delete_prefix("on_")
        calls = []
        key = contract_wire_key(spec, event)
        begin
          control = build_contract_control(spec, event => ->(e) { calls << e })
          patch = control.to_patch
          next "#{event}: patch sends #{patch[key].inspect} for #{key.inspect}, not true" unless patch[key] == true
          next "#{event}: the handler is not attached" unless control.has_handler?(name)

          page = contract_page
          mount_contract_control(page, control)
          next "#{event}: mounting gave no wire id" if control.wire_id.nil?

          page.dispatch_event(target: control.wire_id, name: spec.client_events.fetch(event, name), data: nil)
        rescue StandardError => e
          next "#{event}: #{e.class}: #{e.message}"
        end
        next "#{event}: the handler ran #{calls.size} times" unless calls.size == 1
        next "#{event}: the event names #{calls.first.control.inspect}" unless calls.first.control.equal?(control)
        next "#{event}: the event is named #{calls.first.name.inspect}" unless calls.first.name.to_s == name

        nil
      end

      assert_empty failures, "#{spec.type} events that do not attach and dispatch"
    end
  end

  # Defines the three contract tests for each spec of a family.
  def self.define_tests(test_class, family)
    test_class.include(Assertions)
    family(family).each do |spec|
      test_class.send(:define_method, "test_#{spec.type}_wire_type_and_names") do
        assert_contract_wire_type(spec)
        assert_contract_helper(spec)
      end
      test_class.send(:define_method, "test_#{spec.type}_props_serialize_under_ruby_keys") do
        assert_contract_props(spec)
      end
      test_class.send(:define_method, "test_#{spec.type}_events_attach_and_dispatch") do
        assert_contract_events(spec)
      end
    end
  end
end
