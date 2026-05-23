# frozen_string_literal: true

require_relative "test_helper"

class RufletRailsTest < Minitest::Test
  def test_loads_local_sibling_ruflet_first
    loaded_ruflet = $LOADED_FEATURES.find { |path| path.end_with?("/ruflet_core/lib/ruflet_core.rb") }
    expected = File.expand_path("../../ruflet_core/lib/ruflet_core.rb", __dir__)

    assert_equal expected, loaded_ruflet
  end

  def test_app_loader_captures_entrypoint_without_ruflet_server
    app_file = nil

    Dir.mktmpdir do |dir|
      class_name = "LoaderCaptureApp#{SecureRandom.hex(4)}"
      app_file = File.join(dir, "main.rb")

      File.write(app_file, <<~RUBY)
        require "ruflet"

        class #{class_name} < Ruflet::App
          def view(_page); end
        end

        #{class_name}.new.run
      RUBY

      loaded = Ruflet::Rails::Protocol::MobileLoader.new(app_file).load!

      assert loaded.is_a?(Hash)
      assert loaded[:entrypoint].respond_to?(:call)
    end
  ensure
    File.delete(app_file) if app_file && File.exist?(app_file)
  end

  def test_mobile_endpoint_builder_is_alias_for_app_endpoint_builder
    runner = Ruflet::Rails::Protocol::Runner.new

    assert_equal runner.method(:build_app_endpoint), runner.method(:build_mobile_endpoint)
  end

  def test_load_views_reloads_generated_view_files
    Dir.mktmpdir do |dir|
      view_dir = File.join(dir, "posts")
      FileUtils.mkdir_p(view_dir)
      view_file = File.join(view_dir, "posts_view.rb")

      File.write(view_file, <<~RUBY)
        class ReloadablePostView < RufletView
          route "/old_posts"
        end
      RUBY
      Ruflet::Rails.load_views(dir)
      assert_equal "/old_posts", ReloadablePostView.route

      File.write(view_file, <<~RUBY)
        class ReloadablePostView < RufletView
          route "/new_posts"
        end
      RUBY
      Ruflet::Rails.load_views(dir)
      assert_equal "/new_posts", ReloadablePostView.route
    end
  ensure
    Object.send(:remove_const, :ReloadablePostView) if Object.const_defined?(:ReloadablePostView)
  end
end
