# frozen_string_literal: true

require_relative "test_helper"

class RufletRailsTest < Minitest::Test
  def test_loads_local_sibling_ruflet_first
    loaded_ruflet = $LOADED_FEATURES.find { |path| path.end_with?("/ruflet_core/lib/ruflet_core.rb") }
    expected = File.expand_path("../../ruflet_core/lib/ruflet_core.rb", __dir__)

    assert_equal expected, loaded_ruflet
  end

  def test_app_loader_captures_ruflet_run_entrypoint_for_rails
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

  def test_rails_protocol_uses_shared_ruflet_server_runtime
    assert_same Ruflet::WireCodec, Ruflet::Rails::Protocol::WireCodec
    assert_same Ruflet::WebSocketConnection, Ruflet::Rails::Protocol::WebSocketConnection
  end

  def test_router_renders_route_index_at_root_when_multiple_views_are_registered
    previous_views = Ruflet::Rails.view_classes.dup
    Ruflet::Rails.view_classes.clear

    posts_view = Class.new(RufletView) do
      route "/posts"
      def self.render(page)
        page.add(Ruflet.text("Posts"))
      end
    end
    categories_view = Class.new(RufletView) do
      route "/categories"
      def self.render(page)
        page.add(Ruflet.text("Categories"))
      end
    end
    Ruflet::Rails.register_view(posts_view)
    Ruflet::Rails.register_view(categories_view)

    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    Ruflet::Rails.render(page)

    patch = sent.last[1]["patch"]
    assert find_patch_control(patch, "_c" => "FilledButton", "content" => { "value" => "Categories" })
    assert find_patch_control(patch, "_c" => "FilledButton", "content" => { "value" => "Posts" })

    posts_button = find_patch_control(patch, "_c" => "FilledButton", "content" => { "value" => "Posts" })
    sent.clear
    page.dispatch_event(target: posts_button["_i"], name: "click", data: nil)

    assert find_patch_control(sent.last[1]["patch"], "_c" => "Text", "value" => "Posts")
  ensure
    Ruflet::Rails.view_classes.replace(previous_views) if previous_views
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

  def test_load_views_loads_components_before_view_files
    previous_views = Ruflet::Rails.view_classes.dup
    Ruflet::Rails.view_classes.clear

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "components"))
      FileUtils.mkdir_p(File.join(dir, "posts"))
      File.write(File.join(dir, "components", "application_component.rb"), <<~RUBY)
        class ApplicationComponent
          attr_reader :page

          def self.render(page, *args, **kwargs)
            new(page).render(*args, **kwargs)
          end

          def initialize(page)
            @page = page
          end
        end
      RUBY
      File.write(File.join(dir, "components", "page_title_component.rb"), <<~RUBY)
        class PageTitleComponent < ApplicationComponent
          def render(value)
            text(value)
          end
        end
      RUBY
      File.write(File.join(dir, "posts", "posts_view.rb"), <<~RUBY)
        class ComponentBackedPostView < RufletView
          route "/component_posts"

          def render
            page.add(PageTitleComponent.render(page, "Shared Posts"))
          end
        end
      RUBY

      Ruflet::Rails.load_views(dir)

      assert_equal "/component_posts", ComponentBackedPostView.route
      assert_includes Ruflet::Rails.view_classes, ComponentBackedPostView
    end
  ensure
    Ruflet::Rails.view_classes.replace(previous_views) if previous_views
    Object.send(:remove_const, :ApplicationComponent) if Object.const_defined?(:ApplicationComponent)
    Object.send(:remove_const, :PageTitleComponent) if Object.const_defined?(:PageTitleComponent)
    Object.send(:remove_const, :ComponentBackedPostView) if Object.const_defined?(:ComponentBackedPostView)
  end

  private

  def find_patch_control(value, criteria)
    case value
    when Hash
      return value if patch_control_matches?(value, criteria)

      value.each_value do |child|
        found = find_patch_control(child, criteria)
        return found if found
      end
    when Array
      value.each do |child|
        found = find_patch_control(child, criteria)
        return found if found
      end
    end

    nil
  end

  def patch_control_matches?(control, criteria)
    criteria.all? do |key, expected|
      actual = control[key]
      expected.is_a?(Hash) ? patch_control_matches?(actual || {}, expected) : actual == expected
    end
  end
end
