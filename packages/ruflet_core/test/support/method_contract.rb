# frozen_string_literal: true

require "timeout"

# Contract checks for the public methods of controls and services: what each
# one sends the client (`invoke_control_method`: the control's wire id, the
# method name and its args) and that the client's reply reaches the caller.
#
# Specs live in test/support/method_contracts/*.rb as
# `type => { method => options }`, where options are:
#   args:    positional arguments to call it with (default none)
#   kwargs:  keyword arguments to call it with (default none)
#   name:    the method name the client receives (default: the Ruby name,
#            without a _sync suffix)
#   sends:   the args payload the client receives (default nil)
#   sync:    true when the method blocks for the reply and returns it
#   result:  the reply's result (default "contract result")
#   returns: what a sync method returns for that reply (default: result)
#   local:   why the method sends nothing (it works in Ruby), and where that
#            behaviour is tested; the other options are then not used
#   also:    more calls of the same method, each a Hash of args:, kwargs:
#            and sends: (a default, or a case the main spec does not pass)
# MethodContractCoverageTest fails for any public method without a spec.
module MethodContract
  Spec = Struct.new(:type, :method_name, :args, :kwargs, :name, :sends, :sync, :result, :returns, :local, :also,
                    keyword_init: true)

  DEFAULT_RESULT = "contract result"

  # Props a control cannot be built without.
  BASE = {
    "context_menu" => -> { { content: Ruflet.text("x") } },
    "dismissible" => -> { { content: Ruflet.text("x") } },
    "nested_scroll_view" => -> { { body: Ruflet.text("x") } },
    "screenshot" => -> { { content: Ruflet.text("x") } }
  }.freeze

  @specs = {}

  class << self
    attr_reader :specs

    def define(entries)
      entries.each do |type, methods|
        methods.each do |method_name, options|
          options = options.dup
          spec = Spec.new(
            type: type.to_s,
            method_name: method_name.to_s,
            args: options.delete(:args) || [],
            kwargs: options.delete(:kwargs) || {},
            name: options.delete(:name) || method_name.to_s.delete_suffix("_sync"),
            sends: options.delete(:sends),
            sync: options.delete(:sync) || false,
            result: options.key?(:result) ? options.delete(:result) : DEFAULT_RESULT,
            returns: options.key?(:returns) ? options.delete(:returns) : :result,
            local: options.delete(:local)
          )
          spec.also = Array(options.delete(:also)).map do |call|
            call = call.dup
            extra = spec.dup
            extra.args = call.delete(:args) || []
            extra.kwargs = call.delete(:kwargs) || {}
            extra.sends = call.delete(:sends)
            extra.also = []
            raise ArgumentError, "#{type}##{method_name}: unknown also options #{call.keys}" unless call.empty?

            extra
          end
          raise ArgumentError, "#{type}##{method_name}: unknown options #{options.keys}" unless options.empty?

          key = [spec.type, spec.method_name]
          raise ArgumentError, "#{type}##{method_name} is specified twice" if @specs.key?(key)

          @specs[key] = spec
        end
      end
    end

    def class_for(type)
      Ruflet::UI::ControlFactory::EXTENSION_CLASS_MAP[type] || Ruflet::UI::ControlFactory::CLASS_MAP[type]
    end

    # The public methods a class adds to Ruflet::Control: what an application
    # can call on the control besides building and updating it.
    def public_methods_of(klass)
      (klass.public_instance_methods - Ruflet::Control.public_instance_methods).map(&:to_s).sort
    end

    # Ruflet::Control methods a class replaces with its own client method
    # (flashlight.on turns the light on), so they are part of its surface.
    def overridden_control_methods(klass)
      Ruflet::Control.public_instance_methods(false).select do |name|
        klass.instance_method(name).owner != Ruflet::Control
      end.map(&:to_s).sort
    end
  end

  module Assertions
    private

    def method_contract_control(spec, sent)
      page = Ruflet::Page.new(
        session_id: "contract",
        client_details: { "route" => "/" },
        sender: ->(action, payload) { sent << [action, payload] }
      )
      base = MethodContract::BASE.fetch(spec.type, -> { {} }).call
      control = Ruflet::UI::ControlFactory.build(spec.type, **base)
      if Ruflet::UI::Services::RufletServices::CLASS_MAP.value?(control.class)
        page.add_service(control)
      else
        page.add(control)
      end
      sent.clear
      [page, control]
    end

    def invoke_payloads(sent)
      sent.select { |action, _| action == Ruflet::Protocol::ACTIONS[:invoke_control_method] }.map(&:last)
    end

    def takes_on_result?(control, method_name)
      control.method(method_name).parameters.any? { |kind, name| name == :on_result && %i[key block].include?(kind) }
    end

    def assert_method_contract(spec)
      sent = []
      page, control = method_contract_control(spec, sent)

      if spec.sync
        assert_sync_method_contract(spec, page, control, sent)
      else
        assert_async_method_contract(spec, page, control, sent)
      end
    end

    def assert_invoke_payload(spec, control, payload)
      label = "#{spec.type}##{spec.method_name}"
      refute_nil payload, "#{label} sends invoke_control_method"
      assert_equal control.wire_id, payload["control_id"], "#{label} targets its control"
      assert_equal spec.name, payload["name"], "#{label} method name"
      if spec.sends.nil?
        assert_nil payload["args"], "#{label} args"
      else
        assert_equal spec.sends, payload["args"], "#{label} args"
      end
    end

    def assert_async_method_contract(spec, page, control, sent)
      replies = []
      kwargs = spec.kwargs.dup
      block = nil
      if takes_on_result?(control, spec.method_name)
        if control.method(spec.method_name).parameters.any? { |kind, _| kind == :block }
          block = ->(*reply) { replies << reply }
        else
          kwargs[:on_result] = ->(*reply) { replies << reply }
        end
      end

      call_id = control.public_send(spec.method_name, *spec.args, **kwargs, &block)
      payloads = invoke_payloads(sent)
      assert_equal 1, payloads.size, "#{spec.type}##{spec.method_name} sends one invoke"
      payload = payloads.first
      assert_invoke_payload(spec, control, payload)
      assert_equal payload["call_id"], call_id, "#{spec.type}##{spec.method_name} returns its call id"
      return unless kwargs.key?(:on_result) || block

      assert page.handle_invoke_method_result("call_id" => payload["call_id"], "result" => spec.result, "error" => nil)
      assert_equal [[spec.result, nil]], replies, "#{spec.type}##{spec.method_name} hands the reply to on_result"
    end

    def assert_sync_method_contract(spec, page, control, sent)
      caller = Thread.new { control.public_send(spec.method_name, *spec.args, **spec.kwargs) }
      caller.report_on_exception = false
      payload = Timeout.timeout(2) do
        sleep 0.005 while invoke_payloads(sent).empty?
        invoke_payloads(sent).first
      end
      assert_invoke_payload(spec, control, payload)

      page.handle_invoke_method_result("call_id" => payload["call_id"], "result" => spec.result, "error" => nil)
      expected = spec.returns == :result ? spec.result : spec.returns
      assert_equal expected, caller.value, "#{spec.type}##{spec.method_name} returns the reply"
    ensure
      caller&.kill
    end
  end

  def self.define_tests(test_class, types)
    test_class.include(Assertions)
    @specs.values.select { |spec| types.include?(spec.type) && spec.local.nil? }.each do |spec|
      base = "test_#{spec.type}_#{spec.method_name.sub(/\?\z/, "_p")}_sends_#{spec.name}"
      test_class.send(:define_method, base) { assert_method_contract(spec) }
      spec.also.each_with_index do |extra, index|
        test_class.send(:define_method, "#{base}_call_#{index + 2}") { assert_method_contract(extra) }
      end
    end
  end
end
