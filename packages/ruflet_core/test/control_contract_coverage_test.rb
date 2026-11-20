# frozen_string_literal: true

require_relative "test_helper"
Dir[File.join(__dir__, "support/control_contracts/*.rb")].sort.each { |file| require file }

# Every control and service the factory can build, and every extension
# Ruflet ships, has a contract spec, and every spec family has a test file
# that runs it. A spec's tests check the wire type, that each prop serializes
# under its Ruby wire key, and that each on_* event attaches and dispatches.
# The props and events are the class's constructor keywords, or for an
# open-schema class the ones its spec lists (see
# test/support/control_contract.rb).
class ControlContractCoverageTest < Minitest::Test
  # Registered names with no spec, each with the reason it has none. Keep
  # this empty: a control the factory builds is one an application can send.
  EXCEPTIONS = {}.freeze

  # Open-schema specs that list no props:, each with the reason. Every other
  # open-schema spec lists the props its renderer reads.
  OPEN_SCHEMA_WITHOUT_PROPS = {
    "map_layer" => "Ruby base class of the map layers; the engine has no MapLayer renderer"
  }.freeze

  def test_every_registered_control_and_service_has_a_contract_spec
    specified = ControlContract.specs.values.flat_map { |spec| [spec.type] + spec.aliases }
    missing = ControlContract.registered_names_by_class.filter_map do |klass, names|
      next if names.any? { |name| specified.include?(name) || EXCEPTIONS.key?(name) }

      "#{klass} (#{names.join(", ")})"
    end

    assert_empty missing, "controls with no spec in test/support/control_contracts"
  end

  def test_every_spec_names_a_control_the_factory_builds
    stale = ControlContract.specs.values.flat_map { |spec| [spec.type] + spec.aliases }
                           .reject { |name| ControlContract.class_for(name) }

    assert_empty stale, "spec names the factory no longer resolves"
  end

  def test_each_class_has_one_spec
    by_class = ControlContract.specs.values.group_by { |spec| ControlContract.class_for(spec.type) }
    duplicated = by_class.select { |_klass, specs| specs.size > 1 }
                         .map { |klass, specs| "#{klass}: #{specs.map(&:type).join(", ")}" }

    assert_empty duplicated
  end

  def test_every_type_map_entry_is_a_specified_name
    specified = ControlContract.specs.values.flat_map { |spec| [spec.type] + spec.aliases }

    assert_empty Ruflet::UI::ControlRegistry::TYPE_MAP.keys - specified
  end

  def test_every_spec_family_runs_in_a_test_file
    wired = Dir[File.join(__dir__, "*_test.rb")].flat_map do |file|
      File.read(file, encoding: "utf-8").scan(/ControlContract\.define_tests\(self, "([a-z_]+)"\)/).flatten
    end

    assert_equal ControlContract.specs.values.map(&:family).uniq.sort, wired.uniq.sort
  end

  def test_the_exceptions_have_reasons_and_are_not_stale
    EXCEPTIONS.each do |name, reason|
      assert ControlContract.class_for(name), "#{name} is no longer registered; drop its exception"
      refute ControlContract.specs.key?(name), "#{name} has a spec; drop its exception"
      assert_kind_of String, reason
      refute_empty reason.strip
    end
  end

  def test_open_schema_specs_list_the_props_their_renderer_reads
    open = ControlContract.specs.values.select { |spec| ControlContract.open_schema?(ControlContract.class_for(spec.type)) }
    unlisted = open.select { |spec| spec.props.empty? }.map(&:type)

    assert_equal OPEN_SCHEMA_WITHOUT_PROPS.keys.sort, unlisted.sort,
                 "open-schema specs must list props: (or be explained in OPEN_SCHEMA_WITHOUT_PROPS)"
    OPEN_SCHEMA_WITHOUT_PROPS.each_value { |reason| refute_empty reason.strip }
  end

  def test_shipped_extensions_are_found
    assert_includes ControlContract.shipped_extensions.map(&:name), "qrcode_scanner"
  end
end
