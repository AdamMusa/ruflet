# frozen_string_literal: true

require_relative "test_helper"

class ServiceSchemaCompatibilityTest < Minitest::Test
  def test_every_packaged_service_has_explicit_mruby_safe_schema
    classes = Ruflet::UI::Services::RufletServices::CLASS_MAP.values.uniq

    refute_empty classes
    classes.each do |klass|
      assert klass.const_defined?(:KEYWORDS), "#{klass} must define KEYWORDS for mruby"
      assert_kind_of Array, klass::KEYWORDS
      assert klass::KEYWORDS.all? { |keyword| keyword.is_a?(Symbol) }
    end
  end

  def test_service_schemas_include_properties_and_events_used_by_device_services
    components = Ruflet::UI::Services::RufletServicesComponents

    assert_includes components::ShakeDetectorControl::KEYWORDS, :shake_threshold_gravity
    assert_includes components::ShakeDetectorControl::KEYWORDS, :on_shake
    assert_includes components::SemanticsServiceControl::KEYWORDS, :data
    assert_includes components::PermissionHandlerControl::KEYWORDS, :key
    assert_includes components::AudioRecorderControl::KEYWORDS, :on_state_change
  end
end
