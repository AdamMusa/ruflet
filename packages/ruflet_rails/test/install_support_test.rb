# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class InstallSupportTest < Minitest::Test
  def test_default_ruflet_yaml_contains_rails_config_and_assets
    yaml = Ruflet::Rails::InstallSupport.default_ruflet_yaml(app_name: "Demo")

    assert_includes yaml, "name: Demo"
    assert_includes yaml, "backend_url: http://localhost:3000"
    assert_includes yaml, "icon_launcher: assets/icon.png"
    assert_includes yaml, "services: []"
    refute_includes yaml, "ruflet_client_url"
    refute_includes yaml, "rails:"
    refute_includes yaml, "dir: assets"
  end

  def test_route_snippet_matches_target_agnostic_mount
    route = Ruflet::Rails::InstallSupport.route_snippet(mount_path: "/ws")

    assert_equal 'mount Ruflet::Rails.app(Rails.root.join("app/views/frontend/main.rb")), at: "/ws"', route
  end

  def test_default_entrypoint_path_can_target_mobile_web_or_desktop
    assert_equal "app/views/frontend/main.rb", Ruflet::Rails::InstallSupport.default_entrypoint_path
    assert_equal "app/views/mobile/main.rb", Ruflet::Rails::InstallSupport.default_entrypoint_path(target: "mobile")
    assert_equal "app/views/web/main.rb", Ruflet::Rails::InstallSupport.default_entrypoint_path(target: "web")
    assert_equal "app/views/desktop/main.rb", Ruflet::Rails::InstallSupport.default_entrypoint_path(target: "desktop")
  end

  def test_app_template_uses_ruflet_run
    template = Ruflet::Rails::InstallSupport.default_app_template(app_title: "Demo")

    assert_includes template, 'Ruflet.run do |page|'
    assert_includes template, 'page.title = "Demo"'
    refute_includes template, "Dir["
    assert_includes template, "Ruflet::Rails.render(page)"
  end

  def test_ruflet_view_base_renders_plain_view_classes
    view_class = Class.new(RufletView) do
      def render(value:)
        page[:value] = value
      end
    end
    page = {}

    assert_equal "ok", view_class.render(page, value: "ok")
    assert_equal({ value: "ok" }, page)
  end

  def test_ruflet_view_infers_plural_route_and_allows_override
    view_class = Class.new(RufletView)
    stub_const_name("AdminPostView", view_class) do
      assert_equal "/admin_posts", view_class.route
      view_class.route "/dashboard"
      assert_equal "/dashboard", view_class.route
    end
  end

  def test_rails_view_router_dispatches_by_route_and_first_segment
    posts = Class.new(RufletView) do
      route "/posts"

      def render
        page.rendered = :posts
      end
    end
    categories = Class.new(RufletView) do
      route "/categories"

      def render
        page.rendered = :categories
      end
    end
    page = RouterPage.new("/categories/1?dialog=edit")

    Ruflet::Rails.render(page, routes: { "/posts" => posts, "/categories" => categories }, default: posts)

    assert_equal :categories, page.rendered

    page.route = "/posts"
    page.route_change.call(nil)

    assert_equal :posts, page.rendered
  end

  def test_mobile_app_template_alias_stays_backward_compatible
    assert_equal(
      Ruflet::Rails::InstallSupport.default_app_template(app_title: "Demo"),
      Ruflet::Rails::InstallSupport.default_mobile_app_template(app_title: "Demo")
    )
  end

  def test_scaffold_names_use_rails_inflections
    names = Ruflet::Rails::InstallSupport.scaffold_names("NewsArticle")

    assert_equal "NewsArticle", names[:class_name]
    assert_equal "news_article", names[:singular]
    assert_equal "news_articles", names[:plural]
    assert_equal "News Articles", names[:title]
  end

  def test_scaffold_view_template_is_ruflet_target_agnostic
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "Post",
      attributes: ["title:string", "body:text"]
    )

    assert_includes template, "class PostView < RufletView"
    assert_includes template, 'route "/posts"'
    assert_includes template, "model_class.order(created_at: :desc).limit(50)"
    assert_includes template, "def columns"
    assert_includes template, '["title", "body"]'
    refute_includes template, "COLUMNS ="
    refute_includes template, "FIELDS ="
    refute_includes template, "module RufletScaffolds"
    refute_includes template, "mobile"
  end

  def test_scaffold_view_template_generates_rails_like_crud_views
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "Post",
      attributes: ["title:string", "body:text"]
    )

    assert_includes template, "def index"
    assert_includes template, "def show(record)"
    assert_includes template, "def open_form_dialog(record, title:)"
    assert_includes template, "def save(record, fields)"
    assert_includes template, "width: dialog_width"
    assert_includes template, "def dialog_width"
    assert_includes template, "data_table("
    assert_includes template, "data_column(\"Actions\")"
    assert_includes template, "safe_area("
    assert_includes template, "padding: { left: 24, top: 16, right: 24, bottom: 24 }"
    refute_match(/text\([^\\n]*expand:/, template)
    assert_includes template, "content: text(\"New Post\")"
    assert_includes template, "content: text(record.persisted? ? \"Update Post\" : \"Create Post\")"
    assert_includes template, "record.destroy"
    assert_includes template, "page.show_dialog("
    assert_silent { RubyVM::InstructionSequence.compile(template) }
  end

  def test_scaffold_view_template_generates_type_aware_inputs
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "Event",
      attributes: ["name:string", "body:text", "active:boolean", "starts_on:date", "starts_at:time", "price:decimal", "category:references"]
    )

    assert_includes template, 'def form_fields'
    assert_includes template, '{ name: "name", type: "string" }'
    assert_includes template, '{ name: "category_id", type: "association", class_name: "Category" }'
    assert_includes template, 'when "boolean"'
    assert_includes template, "checkbox(label: label"
    assert_includes template, 'when "association", "references", "belongs_to"'
    assert_includes template, "dropdown("
    assert_includes template, "association_options(field)"
    assert_includes template, 'when "date"'
    assert_includes template, "date_picker("
    assert_includes template, 'when "time"'
    assert_includes template, "time_picker("
    assert_includes template, 'when "integer", "float", "decimal"'
    assert_includes template, 'keyboard_type: "number"'
    assert_includes template, 'when "text"'
    assert_includes template, "multiline: true"
    refute_match(/text_field\([^\\n]*expand:/, template)
    refute_match(/dropdown\([^\\n]*expand:/, template)
    assert_silent { RubyVM::InstructionSequence.compile(template) }
  end

  def test_generated_scaffold_new_button_opens_alert_dialog_through_ruflet_events
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "GeneratedCategory",
      attributes: ["name:string"]
    )
    model_class = stub_scaffold_model("GeneratedCategory")
    Object.class_eval(template.sub(/^require "ruflet_rails"\n\n/, ""))

    sent = []
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: { "route" => "/generated_categories", "width" => 390 },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    GeneratedCategoryView.render(page)
    page.update
    button = find_patch_control(sent.last[1]["patch"], "_c" => "FilledButton", "content" => { "value" => "New Generated Category" })

    refute_nil button

    sent.clear
    page.dispatch_event(target: button["_i"], name: "click", data: nil)
    dialog = sent.last[1]["patch"][1][3].first

    assert_equal "AlertDialog", dialog["_c"]
    assert_equal true, dialog["open"]
    assert_equal 326.0, dialog.dig("content", "width")
    assert_nil dialog.dig("content", "content", "controls", 0, "expand")
  ensure
    Object.send(:remove_const, :GeneratedCategoryView) if Object.const_defined?(:GeneratedCategoryView)
    Object.send(:remove_const, :GeneratedCategory) if Object.const_defined?(:GeneratedCategory) && Object.const_get(:GeneratedCategory) == model_class
  end

  def test_form_view_template_generates_only_reusable_form
    template = Ruflet::Rails::InstallSupport.form_view_template(
      model_name: "Event",
      attributes: ["name:string", "starts_on:date", "active:boolean", "user_id:integer"]
    )

    assert_includes template, "class EventForm < RufletView"
    refute_includes template, "module RufletForms"
    assert_includes template, "def render(record:, title: nil, on_save: nil, on_cancel: nil)"
    assert_includes template, "def save(record, fields, on_save: nil)"
    assert_includes template, "date_picker("
    assert_includes template, "checkbox(label: label"
    assert_includes template, '{ name: "user_id", type: "association", class_name: "User" }'
    assert_includes template, "association_options(field)"
    refute_includes template, "data_table("
    refute_includes template, "record.destroy"
    assert_silent { RubyVM::InstructionSequence.compile(template) }
  end

  def test_form_view_path_uses_rails_views_partial_shape
    assert_equal(
      "app/views/mobile/posts/_form.rb",
      Ruflet::Rails::InstallSupport.form_view_path("Post", target: "mobile")
    )
  end

  def test_attributes_from_model_uses_existing_model_columns
    column = Struct.new(:name, :type)
    model = Class.new do
      local_column = column
      define_singleton_method(:columns) do
        [
          local_column.new("id", :integer),
          local_column.new("title", :string),
          local_column.new("starts_on", :date),
          local_column.new("created_at", :datetime)
        ]
      end
    end

    assert_equal ["title:string", "starts_on:date"], Ruflet::Rails::InstallSupport.attributes_from_model(model)
  end

  def test_scaffold_view_path_defaults_to_frontend_feature_folder
    assert_equal(
      "app/views/frontend/posts/posts_view.rb",
      Ruflet::Rails::InstallSupport.scaffold_view_path("Post")
    )
  end

  def test_scaffold_view_path_can_target_mobile_web_or_desktop
    assert_equal(
      "app/views/mobile/posts/posts_view.rb",
      Ruflet::Rails::InstallSupport.scaffold_view_path("Post", target: "mobile")
    )
    assert_equal(
      "app/views/web/posts/posts_view.rb",
      Ruflet::Rails::InstallSupport.scaffold_view_path("Post", target: "web")
    )
    assert_equal(
      "app/views/desktop/posts/posts_view.rb",
      Ruflet::Rails::InstallSupport.scaffold_view_path("Post", target: "desktop")
    )
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

  def test_build_args_for_rails_web_are_server_driven_and_rails_hosted
    args = Ruflet::Rails::InstallSupport.build_args_for_platform("web")

    assert_equal ["web", "--base-href", "/ruflet/"], args
    refute_includes args, "--self"
  end

  def test_web_base_href_uses_rails_public_subpath
    assert_equal "/ruflet/", Ruflet::Rails::InstallSupport.web_base_href
    assert_equal "/apps/ruflet/", Ruflet::Rails::InstallSupport.web_base_href("/apps/ruflet/")
    assert_equal "/", Ruflet::Rails::InstallSupport.web_base_href("/")
  end

  def test_publish_web_build_copies_build_web_to_public_ruflet
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "build", "web"))
      File.write(File.join(dir, "build", "web", "index.html"), "ok")

      assert Ruflet::Rails::InstallSupport.publish_web_build(dir)
      assert_equal "ok", File.read(File.join(dir, "public", "ruflet", "index.html"))
    end
  end

  def test_publish_web_client_copies_static_release_to_public_ruflet
    Dir.mktmpdir do |dir|
      source = File.join(dir, "cache", "web")
      FileUtils.mkdir_p(source)
      File.write(File.join(source, "index.html"), "prebuilt")
      File.write(File.join(source, "main.dart.js"), "js")

      assert Ruflet::Rails::InstallSupport.publish_web_client(dir, source: source)
      assert_equal "prebuilt", File.read(File.join(dir, "public", "ruflet", "index.html"))
      assert_equal "js", File.read(File.join(dir, "public", "ruflet", "main.dart.js"))
    end
  end

  def test_publish_web_client_requires_static_index
    Dir.mktmpdir do |dir|
      source = File.join(dir, "cache", "web")
      FileUtils.mkdir_p(source)

      refute Ruflet::Rails::InstallSupport.publish_web_client(dir, source: source)
    end
  end

  private

  def stub_const_name(name, value)
    Object.const_set(name, value)
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name) && Object.const_get(name) == value
  end

  def stub_scaffold_model(name)
    model = Class.new do
      def self.order(*)
        self
      end

      def self.limit(*)
        []
      end

      def self.first
        nil
      end

      attr_reader :errors

      def initialize
        @attributes = {}
        @errors = Struct.new(:full_messages).new([])
      end

      def persisted?
        false
      end

      def update(attributes)
        @attributes.merge!(attributes)
        true
      end

      def public_send(name, *args)
        return @attributes[name.to_s] if args.empty? && name.to_s == "name"

        super
      end
    end
    Object.const_set(name, model)
  end

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

  class RouterPage
    attr_accessor :route, :rendered
    attr_reader :route_change

    def initialize(route)
      @route = route
    end

    def on_route_change=(handler)
      @route_change = handler
    end
  end
end
