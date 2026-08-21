# frozen_string_literal: true

require_relative "test_helper"

class RufletAppControlTest < Minitest::Test
  def test_ruflet_app_is_the_canonical_control_name
    control = Ruflet.control(:ruflet_app, url: "http://127.0.0.1:8550", expand: true)

    assert_instance_of Ruflet::UI::Controls::RufletComponents::RufletAppControl, control
    assert_equal "ruflet_app", control.type
  end

  def test_ruflet_app_uses_the_ruflet_wire_type
    patch = Ruflet.control(:ruflet_app, url: "http://127.0.0.1:8550").to_patch

    assert_equal "RufletApp", patch["_c"]
    assert_equal "http://127.0.0.1:8550", patch["url"]
  end

  def test_ruflet_app_serializes_connection_properties
    patch = Ruflet.control(
      :ruflet_app,
      url: "http://127.0.0.1:8550",
      expand: true,
      show_app_startup_screen: true,
      app_startup_screen_message: "Connecting…",
      reconnect_interval_ms: 500,
      reconnect_timeout_ms: 10_000
    ).to_patch

    assert_equal true, patch["expand"]
    assert_equal true, patch["show_app_startup_screen"]
    assert_equal "Connecting…", patch["app_startup_screen_message"]
    assert_equal 500, patch["reconnect_interval_ms"]
    assert_equal 10_000, patch["reconnect_timeout_ms"]
  end

  def test_compact_spelling_resolves_to_the_same_control
    control = Ruflet.control(:rufletapp, url: "http://127.0.0.1:8550")

    assert_instance_of Ruflet::UI::Controls::RufletComponents::RufletAppControl, control
  end

  def test_the_old_flet_names_are_gone
    %i[flet_app fletapp].each do |name|
      control = Ruflet.control(name, url: "http://127.0.0.1:8550")

      refute_instance_of Ruflet::UI::Controls::RufletComponents::RufletAppControl, control, name
    end
  end

  def test_ruflet_app_accepts_the_supplemental_attribute_overrides
    control = Ruflet.control(:ruflet_app, url: "http://127.0.0.1:8550", assets_dir: "assets")

    assert_equal "assets", control.props["assets_dir"]
  end

  def test_ruflet_app_rejects_unknown_keywords
    assert_raises(ArgumentError) do
      Ruflet::UI::Controls::RufletComponents::RufletAppControl.new(not_a_real_prop: 1)
    end
  end
end
