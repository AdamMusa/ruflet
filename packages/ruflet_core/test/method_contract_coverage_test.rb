# frozen_string_literal: true

require_relative "test_helper"
Dir[File.join(__dir__, "support/method_contracts/*.rb")].sort.each { |file| require file }

# Every public method a control, service or shipped extension adds to
# Ruflet::Control (or replaces in it) has a spec in
# test/support/method_contracts: either what it sends the client, or why it
# sends nothing and where that is tested.
class MethodContractCoverageTest < Minitest::Test
  def test_every_public_control_and_service_method_has_a_spec
    missing = classes_by_type.flat_map do |type, klass|
      (MethodContract.public_methods_of(klass) | MethodContract.overridden_control_methods(klass))
        .reject { |name| MethodContract.specs.key?([type, name]) }
        .map { |name| "#{type}##{name}" }
    end

    assert_empty missing, "methods with no spec in test/support/method_contracts"
  end

  def test_every_spec_names_a_public_method
    stale = MethodContract.specs.values.reject do |spec|
      klass = MethodContract.class_for(spec.type)
      klass&.public_method_defined?(spec.method_name)
    end

    assert_empty stale.map { |spec| "#{spec.type}##{spec.method_name}" }
  end

  def test_specs_use_the_name_each_class_is_specified_under
    specified = MethodContract.specs.values.map(&:type).uniq

    assert_empty specified - classes_by_type.keys
  end

  def test_local_methods_say_why_and_where_they_are_tested
    MethodContract.specs.values.select(&:local).each do |spec|
      assert_match(/\(\w+_test\)\z/, spec.local, "#{spec.type}##{spec.method_name} names the test that covers it")
      refute_match(/TODO/, spec.local)
      assert_path_exists File.join(__dir__, "#{spec.local[/\((\w+_test)\)\z/, 1]}.rb")
    end
  end

  private

  # One name per class: the first the factory registers it under, as the
  # control contract specs use.
  def classes_by_type
    types = {}
    Ruflet::UI::ControlFactory::CLASS_MAP.each { |name, klass| types[klass] ||= name }
    lib = File.expand_path("../lib", __dir__)
    Ruflet::Extensions.each do |registration|
      # Only the extensions this gem ships, not ones another test registered.
      next unless Object.const_source_location(registration.control_class.name)&.first&.start_with?(lib)

      types[registration.control_class] ||= registration.name
    end
    types.invert
  end
end
