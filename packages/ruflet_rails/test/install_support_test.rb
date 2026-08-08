# frozen_string_literal: true

require_relative "test_helper"

class InstallSupportTest < Minitest::Test
  def test_default_ruflet_yaml_contains_rails_config_and_assets
    yaml = Ruflet::Rails::InstallSupport.default_ruflet_yaml(app_name: "Demo")

    assert_includes yaml, "name: Demo"
    assert_includes yaml, "backend_url: http://localhost:3000"
    assert_includes yaml, "icon_launcher: assets/icon.png"
    assert_includes yaml, "services: []"
    refute_includes yaml, "ruflet_client_url"
    refute_includes yaml, "rails:"
  end

  def test_default_initializer_contains_build_config
    initializer = Ruflet::Rails::InstallSupport.default_initializer(app_name: "Demo")

    assert_includes initializer, "Ruflet::Rails.configure"
    assert_includes initializer, 'config.app_name = "Demo"'
    assert_includes initializer, "config.backend_url"
    assert_includes initializer, "config.icon_launcher"
  end

  def test_desktop_flag_bootstrap_templates
    ruby = Ruflet::Rails::InstallSupport.ruby_desktop_flag_bootstrap
    shell = Ruflet::Rails::InstallSupport.shell_desktop_flag_bootstrap

    assert_includes ruby, 'ARGV.delete("--desktop")'
    assert_includes ruby, 'ENV["RUFLET_RAILS_DESKTOP"] = "true"'
    assert_includes ruby, 'ENV["RUFLET_RAILS_DESKTOP_SERVER"] = "true"'
    assert_silent { RubyVM::InstructionSequence.compile(ruby) }
    assert_includes shell, '[ "$1" = "--desktop" ]'
    assert_includes shell, "export RUFLET_RAILS_DESKTOP=true"
    assert_includes shell, "export RUFLET_RAILS_DESKTOP_SERVER=true"
    assert_includes shell, "shift"
  end

  def test_route_snippet_matches_exact_websocket_route
    route = Ruflet::Rails::InstallSupport.route_snippet(mount_path: "/ws")

    assert_equal 'match "/ws", to: Ruflet::Rails.native(Rails.root.join("app/views/ruflet/main.rb")), via: :all', route
  end

  def test_default_entrypoint_path_uses_ruflet_views_root
    assert_equal "app/views/ruflet/main.rb", Ruflet::Rails::InstallSupport.default_entrypoint_path
  end


  def test_app_template_uses_ruflet_run
    template = Ruflet::Rails::InstallSupport.default_app_template(app_title: "Demo")

    assert_includes template, "Ruflet.run do |page|"
    assert_includes template, 'page.title = "Demo"'
    assert_includes template, "page.add("
    assert_includes template, "safe_area("
    assert_includes template, "nothing is"
    assert_includes template, "auto-discovered"
    assert_includes template, "mounted explicitly"
    refute_includes template, "Ruflet::Rails.load_views"
    refute_includes template, "Ruflet::Rails.render"
    refute_includes template, 'require "ruflet"'
    assert_silent { RubyVM::InstructionSequence.compile(template) }
  end

  def test_normalize_build_platform_supports_desktop_alias
    platform = Ruflet::Rails::InstallSupport.host_desktop_platform

    assert_equal platform, Ruflet::Rails::InstallSupport.normalize_build_platform("desktop")
    assert_equal "web", Ruflet::Rails::InstallSupport.normalize_build_platform("web")
  end

  def test_build_args_for_rails_desktop_are_server_driven
    args = Ruflet::Rails::InstallSupport.build_args_for_platform("desktop")

    assert_equal Ruflet::Rails::InstallSupport.host_desktop_platform, args.first
    refute_includes args, "--self"
  end


  def test_ruflet_install_steps_include_essentials
    steps = Ruflet::Rails::InstallSupport.install_next_steps(
      target: "ruflet",
      entrypoint: "app/views/ruflet/main.rb",
      client: "none"
    ).join("\n")

    assert_includes steps, "Ruflet Rails installed."
    assert_includes steps, "Generated entrypoint: app/views/ruflet/main.rb"
    assert_includes steps, "Start Rails: bin/rails server"
    assert_includes steps, "ws://localhost:3000/ws"
  end

  def test_ruflet_install_steps_explain_desktop_support
    steps = Ruflet::Rails::InstallSupport.install_next_steps(
      target: "ruflet",
      entrypoint: "app/views/ruflet/main.rb",
      client: "desktop"
    ).join("\n")

    assert_includes steps, "Desktop clients are server-driven and connect to this Rails app."
    assert_includes steps, "Plain bin/dev, bin/rails server, and bin/rails s do not launch desktop."
    assert_includes steps, "bin/rails s --desktop"
    assert_includes steps, "bin/rails ruflet:update[desktop]"
    assert_includes steps, "bin/rails ruflet:build[desktop]"
  end
end
