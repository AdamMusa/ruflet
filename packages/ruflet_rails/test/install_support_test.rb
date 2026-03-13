# frozen_string_literal: true

require_relative "test_helper"

class InstallSupportTest < Minitest::Test
  def test_default_ruflet_yaml_contains_rails_config_and_assets
    yaml = Ruflet::Rails::InstallSupport.default_ruflet_yaml(app_name: "Demo")

    assert_includes yaml, "name: Demo"
    assert_includes yaml, "icon_launcher: assets/icon.png"
    assert_includes yaml, "services: []"
    refute_includes yaml, "rails:"
    refute_includes yaml, "dir: assets"
  end

  def test_route_snippet_matches_mobile_mount
    route = Ruflet::Rails::InstallSupport.route_snippet(
      entrypoint: "app/mobile/main.rb",
      mount_path: "/ws"
    )

    assert_equal 'mount Ruflet::Rails.mobile(Rails.root.join("app/mobile/main.rb")), at: "/ws"', route
  end

  def test_mobile_app_template_uses_ruflet_run
    template = Ruflet::Rails::InstallSupport.default_mobile_app_template(app_title: "Demo")

    assert_includes template, 'Ruflet.run do |page|'
    assert_includes template, 'page.title = "Demo"'
    assert_includes template, "floating_action_button: fab("
  end
end
