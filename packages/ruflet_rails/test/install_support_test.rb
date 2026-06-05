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

  def test_desktop_initializer_template_does_not_enable_autolaunch_by_default
    template = Ruflet::Rails::InstallSupport.desktop_initializer_template

    assert_equal "config/initializers/ruflet_desktop.rb", Ruflet::Rails::InstallSupport.desktop_initializer_path
    assert_includes template, "intentionally want"
    assert_includes template, "config.x.ruflet_rails.desktop = false"
    assert_silent { RubyVM::InstructionSequence.compile(template) }
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

    assert_equal 'match "/ws", to: Ruflet::Rails.app(Rails.root.join("app/views/ruflet/main.rb")), via: :all', route
  end

  def test_default_entrypoint_path_uses_ruflet_views_root
    assert_equal "app/views/ruflet/main.rb", Ruflet::Rails::InstallSupport.default_entrypoint_path
  end

  def test_app_template_uses_ruflet_run
    template = Ruflet::Rails::InstallSupport.default_app_template(app_title: "Demo")

    assert_includes template, 'require "ruflet"'
    assert_includes template, 'require "ruflet_rails"'
    assert_includes template, "Ruflet::Rails.load_views(__dir__)"
    assert_includes template, 'Ruflet.run do |page|'
    assert_includes template, 'page.title = "Demo"'
    assert_includes template, "Ruflet::Rails.render(page)"
  end

  def test_application_component_template_provides_shared_platform_helpers
    template = Ruflet::Rails::InstallSupport.application_component_template

    assert_equal(
      "app/views/ruflet/components/application_component.rb",
      Ruflet::Rails::InstallSupport.application_component_path
    )
    assert_includes template, "class ApplicationComponent"
    assert_includes template, "def self.render(page, *args, **kwargs, &block)"
    assert_includes template, "def desktop?"
    assert_includes template, "def web?"
    assert_includes template, "def mobile?"
    assert_silent { RubyVM::InstructionSequence.compile(template) }
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

  def test_rails_view_router_dispatches_by_exact_route
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
    page = RouterPage.new("/categories")

    Ruflet::Rails.render(page, routes: { "/posts" => posts, "/categories" => categories }, default: posts)

    assert_equal :categories, page.rendered

    page.route = "/categories/1?dialog=edit"
    page.route_change.call(nil)

    assert_equal "Ruflet", page.title
    assert_equal :empty, page.rendered

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

  def test_model_names_use_rails_inflections
    names = Ruflet::Rails::InstallSupport.model_names("NewsArticle")

    assert_equal "NewsArticle", names[:class_name]
    assert_equal "news_article", names[:singular]
    assert_equal "news_articles", names[:plural]
    assert_equal "News Articles", names[:title]
  end

  def test_form_view_template_generates_only_reusable_form
    template = Ruflet::Rails::InstallSupport.form_view_template(
      model_name: "Event",
      attributes: ["name:string", "starts_on:date", "active:boolean", "user_id:integer"]
    )

    assert_includes template, "class EventForm < ApplicationComponent"
    assert_includes template, "include Ruflet::Rails::FormHelpers"
    refute_includes template, "module RufletForms"
    assert_includes template, "def render(record:, title: nil, on_save: nil, on_cancel: nil)"
    assert_includes template, "def save(record, fields, on_save: nil)"
    assert_includes template, "ruflet_form_bindings(record, form_fields)"
    assert_includes template, "ruflet_form_attributes(fields, form_fields)"
    assert_includes template, "def form_fields"
    assert_includes template, "show_errors(record)"
    assert_includes template, "def show_errors(record)"
    assert_includes template, "def show_snackbar(message)"
    assert_includes template, "def error_message(record)"
    refute_includes template, "ruflet_show_errors(record)"
    refute_includes template, "ruflet_show_snackbar"
    refute_includes template, "date_picker("
    refute_includes template, "checkbox(label: label"
    assert_includes template, '{ name: "user_id", type: "association", class_name: "User" }'
    refute_includes template, "association_options(field)"
    refute_includes template, "FIELDS ="
    refute_includes template, "data_table("
    refute_includes template, "record.destroy"
    refute_includes template, "show_dialog(snack_bar"
    assert_silent { RubyVM::InstructionSequence.compile(template) }
  end

  def test_generated_form_component_saves_record_and_calls_callback
    template = Ruflet::Rails::InstallSupport.form_view_template(
      model_name: "Profile",
      attributes: ["name:string", "active:boolean"]
    )
    model_class = stub_model("Profile")
    Object.class_eval(Ruflet::Rails::InstallSupport.application_component_template)
    Object.class_eval(template.sub(/^require "ruflet_rails"\n\n/, ""))

    sent = []
    saved = []
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: { "route" => "/profiles", "width" => 390 },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    record = model_class.new("name" => "Ada", "active" => false)

    form = ProfileForm.render(page, record: record, on_save: ->(_page, saved_record) { saved << saved_record })
    page.add(form)
    save = find_patch_control(sent.last[1]["patch"], "_c" => "FilledButton")
    name_field = find_patch_control(sent.last[1]["patch"], "_c" => "TextField", "label" => "Name")
    active_field = find_patch_control(sent.last[1]["patch"], "_c" => "Checkbox", "label" => "Active")

    refute_nil save
    refute_nil name_field
    refute_nil active_field

    page.apply_client_update(name_field["_i"], "value" => "Grace")
    page.apply_client_update(active_field["_i"], "value" => true)
    page.dispatch_event(target: save["_i"], name: "click", data: nil)

    assert_equal ["Grace"], [record.public_send("name")]
    assert_equal true, record.public_send("active")
    assert_equal [record], saved
  ensure
    Object.send(:remove_const, :ProfileForm) if Object.const_defined?(:ProfileForm)
    Object.send(:remove_const, :Profile) if Object.const_defined?(:Profile) && Object.const_get(:Profile) == model_class
    Object.send(:remove_const, :ApplicationComponent) if Object.const_defined?(:ApplicationComponent)
  end

  def test_generated_form_component_saves_date_picker_values
    template = Ruflet::Rails::InstallSupport.form_view_template(
      model_name: "ScheduledPost",
      attributes: ["title:string", "published_on:date"]
    )
    model_class = stub_model("ScheduledPost")
    Object.class_eval(Ruflet::Rails::InstallSupport.application_component_template)
    Object.class_eval(template.sub(/^require "ruflet_rails"\n\n/, ""))

    sent = []
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: { "route" => "/scheduled_posts", "width" => 390 },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    record = model_class.new("title" => "Draft")

    form = ScheduledPostForm.render(page, record: record)
    page.add(form)
    choose_date = find_patch_control(sent.last[1]["patch"], "_c" => "OutlinedButton", "content" => { "_c" => "Text", "value" => "Choose Published on" })
    save = find_patch_control(sent.last[1]["patch"], "_c" => "FilledButton")

    refute_nil choose_date
    refute_nil save
    assert_nil find_patch_control(sent.last[1]["patch"], "_c" => "DatePicker")

    sent.clear
    page.dispatch_event(target: choose_date["_i"], name: "click", data: nil)
    picker = sent.lazy.filter_map { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "DatePicker") }.first
    refute_nil picker
    assert_equal true, picker["open"]
    assert_equal true, picker["on_change"]

    sent.clear
    page.apply_client_update(picker["_i"], "open" => false, "value" => "2026-05-24T00:00:00+00:00")
    page.dispatch_event(target: picker["_i"], name: "change", data: { "value" => "2026-05-24T00:00:00+00:00" })
    assert dialog_closing?(sent, picker)

    page.dispatch_event(target: save["_i"], name: "click", data: nil)

    assert_equal "2026-05-24", record.public_send("published_on")
  ensure
    Object.send(:remove_const, :ScheduledPostForm) if Object.const_defined?(:ScheduledPostForm)
    Object.send(:remove_const, :ScheduledPost) if Object.const_defined?(:ScheduledPost) && Object.const_get(:ScheduledPost) == model_class
    Object.send(:remove_const, :ApplicationComponent) if Object.const_defined?(:ApplicationComponent)
  end

  def test_form_view_path_uses_rails_views_partial_shape
    assert_equal(
      "app/views/ruflet/components/posts/post_form.rb",
      Ruflet::Rails::InstallSupport.form_view_path("Post")
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

    assert_equal ["web"], args
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

  private

  def stub_const_name(name, value)
    Object.const_set(name, value)
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name) && Object.const_get(name) == value
  end

  def stub_model(name)
    model = Class.new do
      class << self
        attr_accessor :records, :update_result
      end

      def self.order(*)
        self
      end

      def self.limit(*)
        records || []
      end

      def self.first
        (records || []).first
      end

      attr_reader :errors, :destroyed

      def initialize(attributes = {})
        @attributes = { "id" => 1 }.merge(attributes)
        @errors = Struct.new(:full_messages).new([])
        @destroyed = false
      end

      def persisted?
        true
      end

      def update(attributes)
        unless self.class.update_result.nil? || self.class.update_result
          @errors = Struct.new(:full_messages).new(["is invalid"])
          return false
        end

        @attributes.merge!(attributes)
        true
      end

      def id
        @attributes["id"]
      end

      def destroy
        @destroyed = true
      end

      def destroy!
        destroy
      end

      def public_send(name, *args)
        return @attributes[name.to_s] if args.empty?

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

  def dialog_untracked?(sent, dialog)
    sent.any? do |(_action, payload)|
      Array(payload["patch"]).any? do |op|
        op[2] == "controls" && op[3].is_a?(Array) && find_patch_control(op[3], "_i" => dialog["_i"]).nil?
      end
    end
  end

  def dialog_closing?(sent, dialog)
    dialog_untracked?(sent, dialog) || sent.any? do |(_action, payload)|
      payload["id"] == dialog["_i"] && Array(payload["patch"]).any? do |op|
        op[2] == "open" && op[3] == false
      end
    end
  end

  class RouterPage
    attr_accessor :route, :rendered, :title
    attr_reader :route_change

    def initialize(route)
      @route = route
    end

    def on_route_change=(handler)
      @route_change = handler
    end

    def add(*)
      @rendered = :empty
    end

    def update; end
  end

  class ProtocolFakeWebSocket
    attr_reader :sent

    def initialize
      @sent = []
    end

    def session_key
      "protocol-fake-socket"
    end

    def send_binary(payload)
      @sent << payload
    end

    def closed?
      false
    end

    def close; end

    def unpacked_messages
      @sent.map { |payload| Ruflet::Rails::Protocol::WireCodec.unpack(payload) }
    end
  end
end
