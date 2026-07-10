# frozen_string_literal: true

require_relative "test_helper"
require_relative "conformance/component_inventory"
require "json"

class RufletComponentInventoryTest < Minitest::Test
  def test_all_python_flet_controls_are_implemented_or_classified
    inventory = RufletFletComponentInventory.inventory

    assert_equal [], inventory[:unclassified_missing]
  end

  def test_all_classified_services_have_ruflet_service_controls
    inventory = RufletFletComponentInventory.inventory

    assert_equal [], inventory[:service_deferred]
  end

  def test_implemented_python_controls_have_obvious_test_or_conformance_case
    inventory = RufletFletComponentInventory.inventory
    conformance_classes = JSON.parse(File.read(File.expand_path("conformance/flet_cases.json", __dir__)))
                              .fetch("cases")
                              .map { |test_case| test_case.fetch("python_class") }
                              .to_set
    test_text = Dir[File.expand_path("*_test.rb", __dir__)].map { |file| File.read(file) }.join("\n")

    untested = inventory[:implemented].reject do |name|
      conformance_classes.include?(name) || test_text.match?(/#{Regexp.escape(name)}/i)
    end

    assert_equal [], untested
  end

  def test_non_abstract_implemented_python_controls_have_conformance_coverage
    inventory = RufletFletComponentInventory.inventory
    abstract = RufletFletComponentInventory.overrides.fetch("abstract").to_set
    conformance_classes = JSON.parse(File.read(File.expand_path("conformance/flet_cases.json", __dir__)))
                              .fetch("cases")
                              .map { |test_case| test_case.fetch("python_class") }
                              .to_set
    auto_smoke_classes = inventory[:implemented].to_set - conformance_classes - abstract

    uncovered = inventory[:implemented].to_set - conformance_classes - auto_smoke_classes - abstract

    assert_equal [], uncovered.to_a.sort
  end
end
