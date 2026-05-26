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

    assert_equal 'mount Ruflet::Rails.app(Rails.root.join("app/views/ruflet/main.rb")), at: "/ws"', route
  end

  def test_default_entrypoint_path_uses_ruflet_views_root
    assert_equal "app/views/ruflet/main.rb", Ruflet::Rails::InstallSupport.default_entrypoint_path
  end

  def test_app_template_uses_ruflet_run
    template = Ruflet::Rails::InstallSupport.default_app_template(app_title: "Demo")

    assert_includes template, 'require "ruflet"'
    assert_includes template, 'require "ruflet_rails"'
    assert_includes template, 'Ruflet.run do |page|'
    assert_includes template, 'page.title = "Demo"'
    refute_includes template, "Dir["
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
    assert_includes template, "page.add(component.index(records: records), **component.index_view_options)"
    component = Ruflet::Rails::InstallSupport.scaffold_component_template(
      model_name: "Post",
      attributes: ["title:string", "body:text"]
    )
    refute_includes component, "def columns"
    refute_includes component, "def form_fields"
    assert_includes component, 'data_column("Title")'
    assert_includes component, 'record.public_send("title").to_s'
    refute_includes template, "case action.to_sym"
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
    assert_includes template, "def show(record = nil)"
    assert_includes template, "def new(_record = nil)"
    assert_includes template, "def edit(record = nil)"
    assert_includes template, "def update(record, attributes, dialog)"
    refute_includes template, "include Ruflet::Rails::FormHelpers"
    refute_includes template, "def open_form_dialog(record, title:)"

    component = Ruflet::Rails::InstallSupport.scaffold_component_template(
      model_name: "Post",
      attributes: ["title:string", "body:text"]
    )

    assert_includes component, "class PostComponent < ApplicationComponent"
    refute_includes component, "include Ruflet::Rails::FormHelpers"
    assert_includes component, "def open_form_dialog(record, title:)"
    assert_operator component.scan("open: false").length, :>=, 2
    assert_includes component, "width: dialog_width"
    assert_includes component, "def dialog_width"
    assert_includes component, "data_table("
    assert_includes component, 'scroll: "auto"'
    assert_includes component, 'data_column("Actions")'
    refute_includes component, "data_column(icon("
    assert_includes component, 'icon("visibility", tooltip: "Show")'
    assert_match(/icon\("edit",\s+tooltip: "Edit"\)/, component)
    assert_match(/icon\("delete",\s+tooltip: "Delete"\)/, component)
    refute_includes component, 'outlined_icon_button('
    assert_includes component, 'icon_button('
    assert_includes component, "def show_view_options"
    assert_includes component, "def index_view_options"
    assert_includes component, 'leading: icon_button('
    assert_includes component, '"arrow_back"'
    assert_includes component, 'on_click: ->(_e) { page.go("/") }'
    assert_includes component, 'alignment: "end"'
    assert_includes component, '"visibility"'
    assert_includes component, '"edit"'
    assert_includes component, '"delete"'
    assert_match(/tooltip: "Edit"\),\s+on_tap:/, component)
    assert_match(/tooltip: "Delete"\),\s+on_tap:/, component)
    assert_includes component, "safe_area("
    assert_includes component, "padding: { left: 24, top: 16, right: 24, bottom: 24 }"
    refute_match(/text\([^\\n]*expand:/, component)
    refute_match(/text\([^\\n]*width:/, component)
    assert_includes component, "width: 140"
    assert_includes component, "content: text(value, no_wrap: false)"
    assert_includes component, "content: text(\"New Post\")"
    assert_includes component, 'content: text("Save")'
    assert_includes component, "trailing: row("
    assert_includes component, "tight: true"
    assert_includes template, "def close_dialog(dialog)"
    refute_includes component, "ruflet_form_bindings"
    refute_includes component, "ruflet_form_controls"
    refute_includes component, "ruflet_form_attributes"
    refute_includes component, "{ name:"
    assert_includes component, 'title_control = text_field(value: record.public_send("title").to_s, label: "Title", width: dialog_width)'
    assert_includes component, 'body_control = text_field(value: record.public_send("body").to_s, label: "Body", multiline: true, min_lines: 3, width: dialog_width)'
    assert_includes component, '"title" => title_control.props["value"].to_s'
    assert_includes component, '"body" => body_control.props["value"].to_s'
    assert_includes component, "scaffold_error_message(record)"
    assert_includes component, "closing = false"
    assert_includes component, "next if closing"
    assert_includes template, "page.close_dialog(dialog)"
    assert_includes template, "page.update(dialog, open: false)"
    refute_includes template, "page.pop_dialog"
    assert_includes component, "controller.update(record, attributes.call, dialog)"
    assert_includes component, "controller.destroy(record, dialog)"
    refute_includes component, "on_dismiss:"
    refute_includes component, "after_close = -> do"
    refute_includes component, "page.pop_dialog"
    refute_includes component, "show_dialog(snack_bar"
    refute_includes component, "def field_control"
    assert_includes component, "def show_message(message)"
    refute_includes component, "def show_saved_message"
    refute_includes component, "def show_deleted_message"
    assert_includes template, 'component.show_message("Post saved successfully")'
    assert_includes template, 'component.show_message("Post deleted")'
    assert_includes component, "def back_appbar_options(tooltip:, on_click:)"
    assert_includes component, "show_view_options"
    assert_includes component, "index_view_options"
    assert_includes template, "record.destroy"
    assert_includes component, "page.show_dialog("
    assert_silent { RubyVM::InstructionSequence.compile(template) }
    assert_silent { RubyVM::InstructionSequence.compile(component) }
  end

  def test_scaffold_view_template_generates_type_aware_inputs
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "Event",
      attributes: ["name:string", "body:text", "active:boolean", "starts_on:date", "starts_at:time", "price:decimal", "category:references"]
    )

    component = Ruflet::Rails::InstallSupport.scaffold_component_template(
      model_name: "Event",
      attributes: ["name:string", "body:text", "active:boolean", "starts_on:date", "starts_at:time", "price:decimal", "category:references"]
    )
    refute_includes component, 'def form_fields'
    refute_includes component, '{ name: "name", type: "string" }'
    refute_includes component, '{ name: "category_id", type: "association", class_name: "Category" }'
    refute_includes component, "include Ruflet::Rails::FormHelpers"
    refute_includes component, "ruflet_form_bindings"
    assert_includes component, 'name_control = text_field(value: record.public_send("name").to_s, label: "Name", width: dialog_width)'
    assert_includes component, 'body_control = text_field(value: record.public_send("body").to_s, label: "Body", multiline: true, min_lines: 3, width: dialog_width)'
    assert_includes component, 'active_control = checkbox(label: "Active", value: !!record.public_send("active"))'
    assert_includes component, 'starts_on_control = date_picker(value: scaffold_date_value(record.public_send("starts_on")), help_text: "Starts on", open: false)'
    assert_includes component, 'starts_at_control = time_picker(value: record.public_send("starts_at").respond_to?(:strftime) ? record.public_send("starts_at").strftime("%H:%M") : record.public_send("starts_at").to_s, help_text: "Starts at", open: false)'
    assert_includes component, 'on_click: ->(_e) { page.show_dialog(starts_on_control) }'
    assert_includes component, 'on_click: ->(_e) { page.show_dialog(starts_at_control) }'
    assert_includes component, 'page.close_dialog(event.control)'
    refute_includes component, 'on_click: ->(_e) { page.update(starts_on_control, open: true) }'
    refute_includes component, 'on_click: ->(_e) { page.update(starts_at_control, open: true) }'
    assert_includes component, 'price_control = text_field(value: record.public_send("price").to_s, label: "Price", keyboard_type: "number", width: dialog_width)'
    assert_includes component, 'category_id_control = dropdown'
    assert_includes component, 'width: dialog_width'
    assert_includes component, 'outlined_button('
    refute_includes template, 'when "boolean"'
    refute_includes template, "checkbox(label: label"
    refute_includes template, "association_options(field)"
    refute_includes template, "date_picker("
    refute_includes template, "time_picker("
    refute_includes template, 'keyboard_type: "number"'
    refute_includes template, 'when "text"'
    refute_includes template, "multiline: true"
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
    eval_generated_scaffold("GeneratedCategory", ["name:string"])

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
    assert_equal %w[TextButton FilledButton], dialog["actions"].map { |action| action["_c"] }
    assert_equal %w[Cancel Save], dialog["actions"].map { |action| action.dig("content", "value") }
  ensure
    Object.send(:remove_const, :GeneratedCategoryView) if Object.const_defined?(:GeneratedCategoryView)
    Object.send(:remove_const, :GeneratedCategory) if Object.const_defined?(:GeneratedCategory) && Object.const_get(:GeneratedCategory) == model_class
  end

  def test_generated_scaffold_dialog_cancel_closes_with_dialog_update
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "DismissableCategory",
      attributes: ["name:string"]
    )
    model_class = stub_scaffold_model("DismissableCategory")
    eval_generated_scaffold("DismissableCategory", ["name:string"])

    sent = []
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: { "route" => "/dismissable_categories", "width" => 390 },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    DismissableCategoryView.render(page)
    button = find_patch_control(sent.last[1]["patch"], "_c" => "FilledButton", "content" => { "value" => "New Dismissable Category" })

    sent.clear
    page.dispatch_event(target: button["_i"], name: "click", data: nil)
    dialog = sent.last[1]["patch"][1][3].first
    cancel = find_patch_control(dialog, "_c" => "TextButton", "content" => { "value" => "Cancel" })

    refute_nil cancel

    sent.clear
    page.dispatch_event(target: cancel["_i"], name: "click", data: nil)

    assert dialog_closing?(sent, dialog)
  ensure
    Object.send(:remove_const, :DismissableCategoryView) if Object.const_defined?(:DismissableCategoryView)
    Object.send(:remove_const, :DismissableCategory) if Object.const_defined?(:DismissableCategory) && Object.const_get(:DismissableCategory) == model_class
  end

  def test_generated_scaffold_save_closes_dialog_refreshes_index_and_shows_snackbar
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "SavingCategory",
      attributes: ["name:string"]
    )
    model_class = stub_scaffold_model("SavingCategory")
    eval_generated_scaffold("SavingCategory", ["name:string"])

    sent = []
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: { "route" => "/saving_categories", "width" => 390 },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    SavingCategoryView.render(page)
    button = find_patch_control(sent.last[1]["patch"], "_c" => "FilledButton", "content" => { "value" => "New Saving Category" })

    sent.clear
    page.dispatch_event(target: button["_i"], name: "click", data: nil)
    dialog = sent.last[1]["patch"][1][3].first
    save = find_patch_control(dialog, "_c" => "FilledButton", "content" => { "value" => "Save" })

    refute_nil save

    sent.clear
    page.dispatch_event(target: save["_i"], name: "click", data: nil)

    assert dialog_closing?(sent, dialog)
    assert sent.any? { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "Text", "value" => "Saving Categories") }
    assert sent.any? { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "SnackBar", "content" => { "value" => "Saving Category saved successfully" }) }
  ensure
    Object.send(:remove_const, :SavingCategoryView) if Object.const_defined?(:SavingCategoryView)
    Object.send(:remove_const, :SavingCategory) if Object.const_defined?(:SavingCategory) && Object.const_get(:SavingCategory) == model_class
  end

  def test_generated_scaffold_two_category_saves_wait_for_dialog_dismiss_before_refreshing
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "Category",
      attributes: ["name:string"]
    )
    model_class = stub_scaffold_model("Category")
    eval_generated_scaffold("Category", ["name:string"])

    sent = []
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: { "route" => "/categories", "width" => 390, "platform" => "web" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    CategoryView.render(page)
    view_patch = sent.last[1]["patch"]

    2.times do
      button = find_patch_control(view_patch, "_c" => "FilledButton", "content" => { "value" => "New Category" })
      refute_nil button

      sent.clear
      page.dispatch_event(target: button["_i"], name: "click", data: nil)
      dialog = sent.lazy.filter_map { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "AlertDialog") }.first
      save = find_patch_control(dialog, "_c" => "FilledButton", "content" => { "value" => "Save" })

      sent.clear
      page.dispatch_event(target: save["_i"], name: "click", data: nil)
      assert dialog_closing?(sent, dialog)
      assert sent.any? { |(_action, payload)| payload["patch"].any? { |op| op[2] == "views" } }
      assert sent.any? { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "SnackBar", "content" => { "value" => "Category saved successfully" }) }
      view_message = sent.reverse.find { |(_action, payload)| payload["patch"].any? { |op| op[2] == "views" } }
      view_patch = view_message[1]["patch"]
      page.dispatch_event(target: dialog["_i"], name: "dismiss", data: nil)
    end
  ensure
    Object.send(:remove_const, :CategoryView) if Object.const_defined?(:CategoryView)
    Object.send(:remove_const, :Category) if Object.const_defined?(:Category) && Object.const_get(:Category) == model_class
  end

  def test_generated_scaffold_save_click_is_ignored_while_dialog_is_closing
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "DoubleSaveCategory",
      attributes: ["name:string"]
    )
    model_class = stub_scaffold_model("DoubleSaveCategory")
    update_count = 0
    model_class.define_method(:update) do |attributes|
      update_count += 1
      @attributes.merge!(attributes)
      true
    end
    eval_generated_scaffold("DoubleSaveCategory", ["name:string"])

    sent = []
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: { "route" => "/double_save_categories", "width" => 390, "platform" => "web" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    DoubleSaveCategoryView.render(page)
    button = find_patch_control(sent.last[1]["patch"], "_c" => "FilledButton", "content" => { "value" => "New Double Save Category" })
    sent.clear
    page.dispatch_event(target: button["_i"], name: "click", data: nil)
    dialog = sent.lazy.filter_map { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "AlertDialog") }.first
    save = find_patch_control(dialog, "_c" => "FilledButton", "content" => { "value" => "Save" })

    sent.clear
    page.dispatch_event(target: save["_i"], name: "click", data: nil)
    page.dispatch_event(target: save["_i"], name: "click", data: nil)

    assert_equal 1, update_count
    assert dialog_closing?(sent, dialog)
  ensure
    Object.send(:remove_const, :DoubleSaveCategoryView) if Object.const_defined?(:DoubleSaveCategoryView)
    Object.send(:remove_const, :DoubleSaveCategory) if Object.const_defined?(:DoubleSaveCategory) && Object.const_get(:DoubleSaveCategory) == model_class
  end

  def test_generated_scaffold_dialog_click_flows_through_rails_protocol
    Dir.mktmpdir do |dir|
      previous_views = Ruflet::Rails.view_classes.dup
      Ruflet::Rails.view_classes.clear
      component_dir = File.join(dir, "components", "protocol_generated_categories")
      view_dir = File.join(dir, "generated_categories")
      FileUtils.mkdir_p(component_dir)
      FileUtils.mkdir_p(view_dir)
      File.write(File.join(dir, "components", "application_component.rb"), Ruflet::Rails::InstallSupport.application_component_template)
      File.write(
        File.join(component_dir, "protocol_generated_category_component.rb"),
        Ruflet::Rails::InstallSupport.scaffold_component_template(
          model_name: "ProtocolGeneratedCategory",
          attributes: ["name:string"]
        ).sub(/^require "ruflet_rails"\n\n/, "")
      )
      template = Ruflet::Rails::InstallSupport.scaffold_view_template(
        model_name: "ProtocolGeneratedCategory",
        attributes: ["name:string"]
      )
      File.write(File.join(view_dir, "generated_categories_view.rb"), template.sub(/^require "ruflet_rails"\n\n/, ""))
      model_class = stub_scaffold_model("ProtocolGeneratedCategory")
      registry = Ruflet::Rails::SessionRegistry.new
      server = Ruflet::Rails::Protocol::LocalServer.new(session_registry: registry, view_root: dir) do |page|
        Ruflet::Rails.render(page)
      end
      ws = ProtocolFakeWebSocket.new

      server.send(
        :handle_message,
        ws,
        Ruflet::Rails::Protocol::WireCodec.pack([
          Ruflet::Protocol::ACTIONS[:register_client],
          { "session_id" => "protocol-session", "page" => { "route" => "/generated_categories", "width" => 390 } }
        ])
      )
      page_patch_message = ws.unpacked_messages.last
      button = find_patch_control(page_patch_message[1]["patch"], "_c" => "FilledButton", "content" => { "value" => "New Protocol Generated Category" })

      refute_nil button

      ws.sent.clear
      server.send(
        :handle_message,
        ws,
        Ruflet::Rails::Protocol::WireCodec.pack([
          Ruflet::Protocol::ACTIONS[:control_event],
          { "target" => button["_i"], "name" => "click", "data" => nil }
        ])
      )
      dialog_message = ws.unpacked_messages.last
      dialog = dialog_message[1]["patch"][1][3].first

      assert_equal Ruflet::Protocol::ACTIONS[:patch_control], dialog_message[0]
      assert_equal "AlertDialog", dialog["_c"]
      assert_equal true, dialog["open"]
      assert_equal 326.0, dialog.dig("content", "width")
    ensure
      Object.send(:remove_const, :ProtocolGeneratedCategoryView) if Object.const_defined?(:ProtocolGeneratedCategoryView)
      Object.send(:remove_const, :ProtocolGeneratedCategory) if Object.const_defined?(:ProtocolGeneratedCategory) && Object.const_get(:ProtocolGeneratedCategory) == model_class
      Ruflet::Rails.view_classes.replace(previous_views) if previous_views
    end
  end

  def test_generated_scaffold_validation_errors_use_snackbar_without_closing_dialog
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "InvalidCategory",
      attributes: ["name:string"]
    )
    model_class = stub_scaffold_model("InvalidCategory")
    model_class.update_result = false
    eval_generated_scaffold("InvalidCategory", ["name:string"])

    sent = []
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: { "route" => "/invalid_categories", "width" => 390 },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    InvalidCategoryView.render(page)
    button = find_patch_control(sent.last[1]["patch"], "_c" => "FilledButton", "content" => { "value" => "New Invalid Category" })

    sent.clear
    page.dispatch_event(target: button["_i"], name: "click", data: nil)
    dialog = sent.last[1]["patch"][1][3].first
    save = find_patch_control(dialog, "_c" => "FilledButton", "content" => { "value" => "Save" })

    sent.clear
    page.dispatch_event(target: save["_i"], name: "click", data: nil)

    refute sent.any? { |(_action, payload)| payload["id"] == dialog["_i"] && payload["patch"].any? { |op| op[2] == "open" && op[3] == false } }
    assert sent.any? { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "SnackBar", "content" => { "value" => "is invalid" }) }
  ensure
    Object.send(:remove_const, :InvalidCategoryView) if Object.const_defined?(:InvalidCategoryView)
    Object.send(:remove_const, :InvalidCategory) if Object.const_defined?(:InvalidCategory) && Object.const_get(:InvalidCategory) == model_class
  end

  def test_generated_scaffold_table_actions_use_data_cell_taps
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "ActionCategory",
      attributes: ["name:string"]
    )
    model_class = stub_scaffold_model("ActionCategory")
    record = model_class.new("name" => "First")
    model_class.records = [record]
    eval_generated_scaffold("ActionCategory", ["name:string"])

    sent = []
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: { "route" => "/action_categories", "width" => 1024, "platform" => "web" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    ActionCategoryView.render(page)
    patch = sent.last[1]["patch"]
    actions_column = find_patch_control(patch, "_c" => "DataColumn", "label" => "Actions")
    show_cell = find_patch_control(patch, "_c" => "DataCell", "content" => { "_c" => "Icon", "tooltip" => "Show" })
    edit_cell = find_patch_control(patch, "_c" => "DataCell", "content" => { "_c" => "Icon", "tooltip" => "Edit" })
    delete_cell = find_patch_control(patch, "_c" => "DataCell", "content" => { "_c" => "Icon", "tooltip" => "Delete" })

    refute_nil actions_column
    refute_nil show_cell
    refute_nil edit_cell
    refute_nil delete_cell
    assert_equal true, show_cell["on_tap"]
    assert_equal true, edit_cell["on_tap"]
    assert_equal true, delete_cell["on_tap"]

    sent.clear
    page.dispatch_event(target: show_cell["_i"], name: "tap", data: nil)

    show_patch = sent.last[1]["patch"]
    assert find_patch_control(show_patch, "_c" => "Text", "value" => "Action Category #1")
    appbar = find_patch_control(show_patch, "_c" => "AppBar")
    back_button = find_patch_control(appbar, "_c" => "IconButton", "tooltip" => "Back to Action Categories")
    refute_nil appbar
    refute_nil back_button
    assert_equal true, back_button["on_click"]
    refute find_patch_control(show_patch, "_c" => "OutlinedIconButton")
    refute find_patch_control(show_patch, "_c" => "IconButton", "tooltip" => "Show")
    detail_edit = find_patch_control(show_patch, "_c" => "IconButton", "tooltip" => "Edit Action Category")
    detail_delete = find_patch_control(show_patch, "_c" => "IconButton", "tooltip" => "Delete Action Category")
    refute_nil detail_edit
    refute_nil detail_delete
    assert_equal true, detail_edit["on_click"]
    assert_equal true, detail_delete["on_click"]
    assert_kind_of Integer, detail_edit["icon"]
    assert_kind_of Integer, detail_delete["icon"]

    sent.clear
    page.dispatch_event(target: detail_edit["_i"], name: "click", data: nil)

    edit_dialog = sent.lazy.filter_map { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "AlertDialog") }.first
    refute_nil edit_dialog
    edit_save = find_patch_control(edit_dialog, "_c" => "FilledButton", "content" => { "value" => "Save" })
    refute_nil edit_save

    sent.clear
    page.dispatch_event(target: edit_save["_i"], name: "click", data: nil)

    assert dialog_closing?(sent, edit_dialog)
    page.dispatch_event(target: edit_dialog["_i"], name: "dismiss", data: nil)

    ActionCategoryView.render(page)
    patch = sent.last[1]["patch"]
    show_cell = find_patch_control(patch, "_c" => "DataCell", "content" => { "_c" => "Icon", "tooltip" => "Show" })

    sent.clear
    page.dispatch_event(target: show_cell["_i"], name: "tap", data: nil)
    show_patch = sent.last[1]["patch"]
    detail_delete = find_patch_control(show_patch, "_c" => "IconButton", "tooltip" => "Delete Action Category")

    sent.clear
    page.dispatch_event(target: detail_delete["_i"], name: "click", data: nil)

    detail_delete_dialog = sent.lazy.filter_map do |(_action, payload)|
      find_patch_control(payload["patch"], "_c" => "AlertDialog", "title" => { "value" => "Delete Action Category?" })
    end.first
    refute_nil detail_delete_dialog
    detail_delete_cancel = find_patch_control(detail_delete_dialog, "_c" => "TextButton", "content" => { "value" => "Cancel" })
    sent.clear
    page.dispatch_event(target: detail_delete_cancel["_i"], name: "click", data: nil)
    assert dialog_closing?(sent, detail_delete_dialog)
    page.dispatch_event(target: detail_delete_dialog["_i"], name: "dismiss", data: nil)

    ActionCategoryView.render(page)
    patch = sent.last[1]["patch"]
    edit_cell = find_patch_control(patch, "_c" => "DataCell", "content" => { "_c" => "Icon", "tooltip" => "Edit" })

    sent.clear
    page.dispatch_event(target: edit_cell["_i"], name: "tap", data: nil)

    table_edit_dialog = sent.lazy.filter_map { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "AlertDialog") }.first
    refute_nil table_edit_dialog
    table_edit_cancel = find_patch_control(table_edit_dialog, "_c" => "TextButton", "content" => { "value" => "Cancel" })
    sent.clear
    page.dispatch_event(target: table_edit_cancel["_i"], name: "click", data: nil)
    assert dialog_closing?(sent, table_edit_dialog)
    page.dispatch_event(target: table_edit_dialog["_i"], name: "dismiss", data: nil)

    ActionCategoryView.render(page)
    patch = sent.last[1]["patch"]
    delete_cell = find_patch_control(patch, "_c" => "DataCell", "content" => { "_c" => "Icon", "tooltip" => "Delete" })

    sent.clear
    page.dispatch_event(target: delete_cell["_i"], name: "tap", data: nil)

    refute record.destroyed
    delete_dialog = sent.lazy.filter_map do |(_action, payload)|
      find_patch_control(payload["patch"], "_c" => "AlertDialog", "title" => { "value" => "Delete Action Category?" })
    end.first
    refute_nil delete_dialog
    assert_equal "Permanently remove Action Category #1? This cannot be undone.", delete_dialog.dig("content", "value")

    confirm = find_patch_control(delete_dialog, "_c" => "FilledButton", "content" => { "value" => "Delete" })
    refute_nil confirm

    sent.clear
    page.dispatch_event(target: confirm["_i"], name: "click", data: nil)

    assert_equal true, record.destroyed
    assert dialog_closing?(sent, delete_dialog)
    assert sent.any? { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "SnackBar", "content" => { "value" => "Action Category deleted" }) }
  ensure
    Object.send(:remove_const, :ActionCategoryView) if Object.const_defined?(:ActionCategoryView)
    Object.send(:remove_const, :ActionCategory) if Object.const_defined?(:ActionCategory) && Object.const_get(:ActionCategory) == model_class
  end

  def test_generated_scaffold_index_and_show_display_back_on_all_platforms
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "WebCategory",
      attributes: ["name:string"]
    )
    model_class = stub_scaffold_model("WebCategory")
    record = model_class.new("name" => "First")
    model_class.records = [record]
    eval_generated_scaffold("WebCategory", ["name:string"])

    %w[web macos windows linux].each do |platform|
      sent = []
      page = Ruflet::Page.new(
        session_id: "test-session-#{platform}",
        client_details: { "route" => "/web_categories", "width" => 1024, "platform" => platform },
        sender: ->(action, payload) { sent << [action, payload] }
      )

      WebCategoryView.render(page)
      index_appbar = find_patch_control(sent.last[1]["patch"], "_c" => "AppBar")
      index_back = find_patch_control(index_appbar, "_c" => "IconButton", "tooltip" => "Back")

      refute_nil index_appbar, "expected index appbar for #{platform}"
      refute_nil index_back, "expected index back button for #{platform}"

      WebCategoryView.render(page, action: :show, record: record)
      show_appbar = find_patch_control(sent.last[1]["patch"], "_c" => "AppBar")
      show_back = find_patch_control(show_appbar, "_c" => "IconButton", "tooltip" => "Back to Web Categories")

      refute_nil show_appbar, "expected show appbar for #{platform}"
      refute_nil show_back, "expected show back button for #{platform}"
    end
  ensure
    Object.send(:remove_const, :WebCategoryView) if Object.const_defined?(:WebCategoryView)
    Object.send(:remove_const, :WebCategory) if Object.const_defined?(:WebCategory) && Object.const_get(:WebCategory) == model_class
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
    assert_includes template, "ruflet_show_errors(record)"
    refute_includes template, "def show_errors(record)"
    refute_includes template, "def error_message(record)"
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
    model_class = stub_scaffold_model("Profile")
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
    model_class = stub_scaffold_model("ScheduledPost")
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
    picker = find_patch_control(sent.last[1]["patch"], "_c" => "DatePicker")

    refute_nil choose_date
    refute_nil save
    refute_nil picker
    assert_equal true, picker["on_change"]

    sent.clear
    page.dispatch_event(target: choose_date["_i"], name: "click", data: nil)
    assert picker_opening?(sent, picker)

    sent.clear
    page.apply_client_update(picker["_i"], "open" => false, "value" => "2026-05-24T00:00:00+00:00")
    page.dispatch_event(target: picker["_i"], name: "change", data: { "value" => "2026-05-24T00:00:00+00:00" })
    assert picker_closing?(sent, picker)
    refute sent.any? { |(_action, payload)| Array(payload["patch"]).any? { |op| op[2] == "controls" } }

    page.dispatch_event(target: save["_i"], name: "click", data: nil)

    assert_equal "2026-05-24", record.public_send("published_on")
  ensure
    Object.send(:remove_const, :ScheduledPostForm) if Object.const_defined?(:ScheduledPostForm)
    Object.send(:remove_const, :ScheduledPost) if Object.const_defined?(:ScheduledPost) && Object.const_get(:ScheduledPost) == model_class
    Object.send(:remove_const, :ApplicationComponent) if Object.const_defined?(:ApplicationComponent)
  end

  def test_generated_scaffold_edit_saves_changed_date_and_closes_form
    template = Ruflet::Rails::InstallSupport.scaffold_view_template(
      model_name: "DatedPost",
      attributes: ["title:string", "published_on:date"]
    )
    model_class = stub_scaffold_model("DatedPost")
    record = model_class.new("title" => "Draft", "published_on" => "2026-05-24")
    model_class.records = [record]
    eval_generated_scaffold("DatedPost", ["title:string", "published_on:date"])

    sent = []
    page = Ruflet::Page.new(
      session_id: "test-session",
      client_details: { "route" => "/dated_posts", "width" => 1000 },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    DatedPostView.render(page)
    edit_cell = find_patch_control(sent.last[1]["patch"], "_c" => "DataCell", "content" => { "_c" => "Icon", "tooltip" => "Edit" })
    refute_nil edit_cell

    sent.clear
    page.dispatch_event(target: edit_cell["_i"], name: "tap", data: nil)
    dialog = sent.lazy.filter_map { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "AlertDialog") }.first
    refute_nil dialog

    choose_date = find_patch_control(dialog, "_c" => "OutlinedButton", "content" => { "_c" => "Text", "value" => "Choose Published on" })
    save = find_patch_control(dialog, "_c" => "FilledButton", "content" => { "value" => "Save" })
    refute_nil choose_date
    refute_nil save
    assert_nil find_patch_control(dialog, "_c" => "DatePicker")

    sent.clear
    page.dispatch_event(target: choose_date["_i"], name: "click", data: nil)
    picker = sent.lazy.filter_map { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "DatePicker") }.first
    refute_nil picker
    assert_equal true, picker["open"]
    assert_equal true, picker["on_change"]

    sent.clear
    page.apply_client_update(picker["_i"], "open" => false, "value" => "2026-05-27T00:00:00+00:00")
    page.dispatch_event(target: picker["_i"], name: "change", data: { "value" => "2026-05-27T00:00:00+00:00" })
    assert dialog_closing?(sent, picker)

    sent.clear
    page.dispatch_event(target: save["_i"], name: "click", data: nil)

    assert_equal "2026-05-27", record.public_send("published_on")
    assert dialog_closing?(sent, dialog)
    assert sent.any? { |(_action, payload)| find_patch_control(payload["patch"], "_c" => "SnackBar", "content" => { "value" => "Dated Post saved successfully" }) }
  ensure
    Object.send(:remove_const, :DatedPostView) if Object.const_defined?(:DatedPostView)
    Object.send(:remove_const, :DatedPost) if Object.const_defined?(:DatedPost) && Object.const_get(:DatedPost) == model_class
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

  def test_scaffold_view_path_defaults_to_ruflet_feature_folder
    assert_equal(
      "app/views/ruflet/posts/posts_view.rb",
      Ruflet::Rails::InstallSupport.scaffold_view_path("Post")
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

    assert_equal ["web", "--base-href", "/app/"], args
    refute_includes args, "--self"
  end

  def test_web_base_href_uses_rails_public_subpath
    assert_equal "/app/", Ruflet::Rails::InstallSupport.web_base_href
    assert_equal "/apps/ruflet/", Ruflet::Rails::InstallSupport.web_base_href("/apps/ruflet/")
    assert_equal "/", Ruflet::Rails::InstallSupport.web_base_href("/")
  end

  def test_publish_web_build_copies_build_web_to_public_ruflet
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "build", "web"))
      File.write(File.join(dir, "build", "web", "index.html"), '<html><head><base href="/"></head></html>')

      assert Ruflet::Rails::InstallSupport.publish_web_build(dir)
      assert_includes File.read(File.join(dir, "public", "app", "index.html")), '<base href="/app/">'
    end
  end

  def test_publish_web_client_copies_static_release_to_public_ruflet
    Dir.mktmpdir do |dir|
      source = File.join(dir, "cache", "web")
      FileUtils.mkdir_p(source)
      File.write(File.join(source, "index.html"), '<html><head><base href="/"></head><body>prebuilt</body></html>')
      File.write(File.join(source, "main.dart.js"), "js")

      assert Ruflet::Rails::InstallSupport.publish_web_client(dir, source: source)
      index = File.read(File.join(dir, "public", "app", "index.html"))
      assert_includes index, "prebuilt"
      assert_includes index, '<base href="/app/">'
      refute_includes index, "data-ruflet-rails-bootstrap"
      refute_includes index, 'params.set("url", window.location.origin)'
      refute_includes index, 'URLSearchParams'
      refute_includes index, "window.flet"
      refute_includes index, "webSocketEndpoint"
      assert_equal "js", File.read(File.join(dir, "public", "app", "main.dart.js"))
    end
  end

  def test_publish_web_client_inserts_base_href_when_missing
    Dir.mktmpdir do |dir|
      source = File.join(dir, "cache", "web")
      FileUtils.mkdir_p(source)
      File.write(File.join(source, "index.html"), "<html><head></head><body></body></html>")

      assert Ruflet::Rails::InstallSupport.publish_web_client(dir, source: source, public_path: "apps/ruflet")
      assert_includes File.read(File.join(dir, "public", "apps", "ruflet", "index.html")), '<base href="/apps/ruflet/">'
    end
  end

  def test_publish_web_client_requires_static_index
    Dir.mktmpdir do |dir|
      source = File.join(dir, "cache", "web")
      FileUtils.mkdir_p(source)

      refute Ruflet::Rails::InstallSupport.publish_web_client(dir, source: source)
    end
  end

  def test_ruflet_install_steps_explain_web_public_copy_and_wasm_build
    steps = Ruflet::Rails::InstallSupport.install_next_steps(
      target: "ruflet",
      entrypoint: "app/views/ruflet/main.rb",
      client: "web",
      web_published: false
    ).join("\n")

    assert_includes steps, "Ruflet Rails installed."
    assert_includes steps, "Generated entrypoint: app/views/ruflet/main.rb"
    assert_includes steps, "Open the Ruflet web client: /app/"
    assert_includes steps, "bin/rails ruflet:update[web]"
    assert_includes steps, "gem install ruflet"
    assert_includes steps, "bin/rails ruflet:build[web]"
    assert_includes steps, "public/app"
  end

  def test_ruflet_install_steps_confirm_published_web_client
    steps = Ruflet::Rails::InstallSupport.install_next_steps(
      target: "ruflet",
      entrypoint: "app/views/ruflet/main.rb",
      client: "web",
      web_published: true
    ).join("\n")

    assert_includes steps, "Web client copied to public/app."
    refute_includes steps, "gem install ruflet"
  end

  def test_ruflet_install_steps_explain_desktop_support
    steps = Ruflet::Rails::InstallSupport.install_next_steps(
      target: "ruflet",
      entrypoint: "app/views/ruflet/main.rb",
      client: "desktop",
      web_published: false
    ).join("\n")

    assert_includes steps, "Desktop clients are server-driven and connect to this Rails app."
    assert_includes steps, "bin/rails ruflet:update[desktop]"
    assert_includes steps, "bin/rails ruflet:build[desktop]"
  end

  private

  def eval_generated_scaffold(model_name, attributes)
    Object.class_eval(Ruflet::Rails::InstallSupport.application_component_template) unless Object.const_defined?(:ApplicationComponent)
    Object.class_eval(
      Ruflet::Rails::InstallSupport.scaffold_component_template(
        model_name: model_name,
        attributes: attributes
      ).sub(/^require "ruflet_rails"\n\n/, "")
    )
    Object.class_eval(
      Ruflet::Rails::InstallSupport.scaffold_view_template(
        model_name: model_name,
        attributes: attributes
      ).sub(/^require "ruflet_rails"\n\n/, "")
    )
  end

  def stub_const_name(name, value)
    Object.const_set(name, value)
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name) && Object.const_get(name) == value
  end

  def stub_scaffold_model(name)
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

  def picker_opening?(sent, picker)
    sent.any? do |(_action, payload)|
      payload["id"] == picker["_i"] && Array(payload["patch"]).any? do |op|
        op[2] == "open" && op[3] == true
      end
    end
  end

  def picker_closing?(sent, picker)
    sent.any? do |(_action, payload)|
      payload["id"] == picker["_i"] && Array(payload["patch"]).any? do |op|
        op[2] == "open" && op[3] == false
      end
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
