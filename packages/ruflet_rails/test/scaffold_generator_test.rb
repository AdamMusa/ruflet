# frozen_string_literal: true

require_relative "test_helper"

local_lib = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(local_lib) unless $LOAD_PATH.include?(local_lib)

require "rails/generators"
require "generators/ruflet/scaffold/scaffold_generator"

class RufletScaffoldGeneratorTest < Minitest::Test
  RailsGenerators = ::Rails::Generators

  def test_rails_generator_creates_a_single_mountable_component
    Dir.mktmpdir do |dir|
      capture_io do
        RailsGenerators.invoke(
          "ruflet:scaffold",
          ["Post", "title:string", "body:text"],
          destination_root: dir
        )
      end

      # The generator emits ONE file: the resource component. No separate view
      # host — routing, model resolution and persistence all live in the base
      # class (Ruflet::Rails::ResourceComponent).
      refute File.exist?(File.join(dir, "app/views/ruflet/posts_view.rb")),
             "the scaffold must not generate a separate view file"

      component_path = File.join(dir, "app/views/ruflet/components/posts/post_component.rb")
      component_source = File.read(component_path)

      assert_includes component_source, "class PostComponent < Ruflet::Rails::ResourceComponent"
      assert_includes component_source, "def render"
      assert_includes component_source, "def show(record)"
      assert_includes component_source, "def record_table"
      assert_includes component_source, "def open_form"
      assert_includes component_source, "show_record(record)"
      assert_includes component_source, "data_table("
      assert_includes component_source, "alert_dialog("
      assert_includes component_source, "open: false"
      assert_includes component_source, "title_control = text_field"
      assert_includes component_source, "body_control = text_field"
      assert_includes component_source, '"title" => title_control.value.to_s'
      assert_includes component_source, '"body" => body_control.value.to_s'
      assert_includes component_source, "save_record(record, attributes.call, dialog)"
      assert_includes component_source, "open_dialog(dialog)"
      assert_includes component_source, "close_dialog(dialog)"

      # The app-specific field configuration lives in the component (the part a
      # developer customizes) ...
      assert_includes component_source, "def resource_fields"
      assert_includes component_source, "def display_fields"
      assert_includes component_source, "def display_value(record, field)"
      assert_includes component_source, '["title", "body"]'

      # ... but the generic plumbing does NOT — it is inherited.
      refute_includes component_source, "class PostView"
      refute_includes component_source, "Ruflet::Rails::ResourceView"
      refute_includes component_source, 'route "/posts"'
      refute_includes component_source, "def model_class"
      refute_includes component_source, "def records"
      refute_includes component_source, "def save_record"
      refute_includes component_source, "def destroy_record"
      refute_includes component_source, "def render_index"
      refute_includes component_source, "def render_show"
      refute_includes component_source, "def component"
      refute_includes component_source, ".new(page, controller: self)"
      refute_includes component_source, "page.dialog = dialog"
      refute_includes component_source, "page.update(dialog, open: false)"
      refute_includes component_source, "ruflet_form_bindings"
      refute_includes component_source, "ruflet_form_attributes"
      refute_includes component_source, "title:string"
      refute_includes component_source, "body:text"
      refute_includes component_source, "{ name:"
      refute File.exist?(File.join(dir, "app/views/ruflet/components/application_component.rb"))
    end
  end

  def test_scaffold_without_date_attributes_generates_valid_ruby
    component = Ruflet::Rails::InstallSupport.scaffold_component_template(
      model_name: "Product",
      attributes: ["name:string", "price:decimal", "description:text"]
    )

    # A case expression with no when clause is a syntax error.
    refute_match(/case field\s*\n\s*else/, component)
    assert_includes component, "def display_value(record, field)"
    assert_silent_syntax component
  end

  def assert_silent_syntax(source)
    RubyVM::InstructionSequence.compile(source)
  rescue SyntaxError => e
    flunk "generated code has a syntax error: #{e.message}"
  end

  def test_scaffold_form_inputs_stretch_to_the_dialog_width
    component = Ruflet::Rails::InstallSupport.scaffold_component_template(
      model_name: "Product",
      attributes: ["name:string", "price:decimal", "description:text"]
    )

    # The form's content column must stretch its children so the inputs fill
    # the dialog width instead of rendering at small/intrinsic width.
    form_column = component[/content: container\(\s*width: dialog_width,.*?\n\s*\),\s*\n\s*actions:/m]
    refute_nil form_column, "could not locate the form content container"
    assert_includes form_column, 'horizontal_alignment: "stretch"',
                    "form inputs should stretch to the dialog width"
    assert_silent_syntax component
  end

  def test_scaffold_component_keeps_attribute_metadata_out_of_generated_file
    component_source = Ruflet::Rails::InstallSupport.scaffold_component_template(
      model_name: "NewsArticle",
      attributes: ["headline:string", "published:boolean"]
    )

    assert_includes component_source, "class NewsArticleComponent < Ruflet::Rails::ResourceComponent"
    assert_includes component_source, "def render"
    assert_includes component_source, "def show(record)"
    assert_includes component_source, "def record_table"
    assert_includes component_source, "def open_form"
    assert_includes component_source, "show_record(record)"
    assert_includes component_source, "open_dialog(dialog)"
    assert_includes component_source, "headline_control = text_field"
    assert_includes component_source, "published_control = checkbox"
    assert_includes component_source, '"headline" => headline_control.value.to_s'
    assert_includes component_source, '"published" => !!published_control.value'
    assert_includes component_source, "def resource_fields"
    assert_includes component_source, '["headline", "published"]'

    # Generic plumbing is inherited, not generated.
    refute_includes component_source, "Ruflet::Rails::ResourceView"
    refute_includes component_source, 'route "/news_articles"'
    refute_includes component_source, "def model_class"
    refute_includes component_source, "def records"
    refute_includes component_source, "def save_record"
    refute_includes component_source, "model_class.columns"
    refute_includes component_source, "ignored_column?"
    refute_includes component_source, "association_class_name_for_column"

    refute_includes component_source, "headline:string"
    refute_includes component_source, "published:boolean"
    refute_includes component_source, "title:string"
    refute_includes component_source, "{ name:"
    refute_includes component_source, "ruflet_form_bindings"
    refute_includes component_source, "ruflet_form_attributes"
    refute_includes component_source, "ruflet_show"
  end

  def test_scaffold_generates_date_picker_for_date_attributes
    component_source = Ruflet::Rails::InstallSupport.scaffold_component_template(
      model_name: "Post",
      attributes: ["title:string", "publish_on:date"]
    )

    assert_includes component_source, 'require "date"'
    assert_includes component_source, "publish_on_control = date_picker("
    assert_includes component_source, "publish_on_control_value = date_picker_value(record.public_send(\"publish_on\"))"
    assert_includes component_source, "publish_on_control_display = text(date_display_value(publish_on_control_value))"
    assert_includes component_source, "open_dialog(publish_on_control)"
    assert_includes component_source, "close_dialogs(publish_on_control)"
    assert_includes component_source, "close_dialog(dialog)"
    assert_includes component_source, "save_record(record, attributes.call, dialog)"
    assert_includes component_source, "publish_on_control_field"
    assert_includes component_source, '"publish_on" => publish_on_control.value.to_s.split("T", 2).first'
    refute_includes component_source, "page.update(dialog, open: false)"
    refute_includes component_source, 'publish_on_control = text_field'
    refute_includes component_source, "dropdown("
  end

  def test_scaffold_generates_time_and_date_range_pickers
    component_source = Ruflet::Rails::InstallSupport.scaffold_component_template(
      model_name: "Event",
      attributes: ["starts_at:time", "booking_window:daterange"]
    )

    assert_includes component_source, "starts_at_control = time_picker("
    assert_includes component_source, "starts_at_control_value = time_picker_value(record.public_send(\"starts_at\"))"
    assert_includes component_source, "starts_at_control_display = text(time_display_value(starts_at_control_value))"
    assert_includes component_source, '"starts_at" => starts_at_control.value.to_s'
    assert_includes component_source, "booking_window_control = date_range_picker("
    assert_includes component_source, "booking_window_control_start_value, booking_window_control_end_value = date_range_picker_values(record.public_send(\"booking_window\"))"
    assert_includes component_source, "date_range_display_value(booking_window_control.start_value, booking_window_control.end_value)"
    assert_includes component_source, '"booking_window" => Range.new(Date.parse(booking_window_control.start_value.to_s), Date.parse(booking_window_control.end_value.to_s))'
    assert_includes component_source, "close_dialogs(starts_at_control)"
    assert_includes component_source, "close_dialogs(booking_window_control)"
    refute_includes component_source, "event.control"
    refute_includes component_source, "page.dialog ="
    refute_includes component_source, "page.update(dialog, open: false)"
  end

  def test_generated_scaffold_new_form_cancel_closes_after_date_picker_change
    install_generated_scaffold("ScheduledPost", ["title:string", "publish_on:date"]) do |model_class|
      model_class.records = []
      sent = []
      page = Ruflet::Page.new(
        session_id: "test-session",
        client_details: { "route" => "/scheduled_posts", "width" => 1280 },
        sender: ->(action, payload) { sent << [action, payload] }
      )

      ScheduledPostComponent.render(page)
      new_button = find_patch_control(sent.last[1]["patch"], "_c" => "FilledButton", "content" => { "_c" => "Text", "value" => "New Scheduled Post" })
      refute_nil new_button

      sent.clear
      page.dispatch_event(target: new_button["_i"], name: "click", data: nil)
      dialog = find_last_patch_control(sent, "_c" => "AlertDialog")
      choose_date = find_last_patch_control(sent, "_c" => "OutlinedButton", "content" => { "_c" => "Text", "value" => "Choose Publish on" })
      cancel = find_last_patch_control(sent, "_c" => "TextButton", "content" => { "_c" => "Text", "value" => "Cancel" })

      refute_nil dialog
      refute_nil choose_date
      refute_nil cancel

      sent.clear
      page.dispatch_event(target: choose_date["_i"], name: "click", data: nil)
      picker = find_last_patch_control(sent, "_c" => "DatePicker")

      refute_nil picker
      assert_equal true, picker["open"]

      sent.clear
      page.apply_client_update(picker["_i"], "open" => false, "value" => "2026-06-03T00:00:00+00:00")
      page.dispatch_event(target: picker["_i"], name: "change", data: { "value" => "2026-06-03T00:00:00+00:00" })

      refute dialog_stack_contains?(sent, picker["_i"])

      sent.clear
      page.dispatch_event(target: cancel["_i"], name: "click", data: nil)

      assert dialog_stack_empty?(sent)
      refute dialog_stack_contains?(sent, dialog["_i"])
    end
  end

  def test_generated_scaffold_save_closes_form_dialog_without_reopening_unopened_picker
    install_generated_scaffold("ScheduledPost", ["title:string", "publish_on:date"]) do |model_class|
      record = model_class.new("title" => "Draft", "publish_on" => Date.iso8601("2026-05-26"))
      model_class.records = [record]
      sent = []
      page = Ruflet::Page.new(
        session_id: "test-session",
        client_details: { "route" => "/scheduled_posts", "width" => 1280 },
        sender: ->(action, payload) { sent << [action, payload] }
      )

      ScheduledPostComponent.render(page)
      edit = find_data_cell_by_icon_tooltip(sent.last[1]["patch"], "Edit")
      refute_nil edit

      sent.clear
      page.dispatch_event(target: edit["_i"], name: "tap", data: nil)
      dialog = find_last_patch_control(sent, "_c" => "AlertDialog")
      save = find_last_patch_control(sent, "_c" => "FilledButton")

      refute_nil dialog
      refute_nil save
      assert_equal true, dialog["open"]

      sent.clear
      page.dispatch_event(target: save["_i"], name: "click", data: nil)

      assert dialog_stack_empty?(sent)
      refute dialog_stack_contains?(sent, dialog["_i"]),
             "save should not re-patch the still-open form dialog while closing an unopened picker"
    end
  end

  def test_generated_scaffold_picker_change_closes_nested_picker_and_then_save_closes_form
    install_generated_scaffold("ScheduledPost", ["title:string", "publish_on:date"]) do |model_class|
      record = model_class.new("title" => "Draft", "publish_on" => Date.iso8601("2026-05-26"))
      model_class.records = [record]
      sent = []
      page = Ruflet::Page.new(
        session_id: "test-session",
        client_details: { "route" => "/scheduled_posts", "width" => 1280 },
        sender: ->(action, payload) { sent << [action, payload] }
      )

      ScheduledPostComponent.render(page)
      edit = find_data_cell_by_icon_tooltip(sent.last[1]["patch"], "Edit")

      sent.clear
      page.dispatch_event(target: edit["_i"], name: "tap", data: nil)
      choose_date = find_last_patch_control(sent, "_c" => "OutlinedButton", "content" => { "_c" => "Text", "value" => "Choose Publish on" })
      date_display = find_last_patch_control(sent, "_c" => "Text", "value" => "2026-05-26")
      save = find_last_patch_control(sent, "_c" => "FilledButton")
      form_dialog = find_last_patch_control(sent, "_c" => "AlertDialog")
      refute_nil choose_date
      refute_nil date_display

      sent.clear
      page.dispatch_event(target: choose_date["_i"], name: "click", data: nil)
      picker = find_last_patch_control(sent, "_c" => "DatePicker")
      refute_nil picker
      assert_equal true, picker["open"]

      sent.clear
      page.apply_client_update(picker["_i"], "open" => false, "value" => "2026-06-02T00:00:00+00:00")
      page.dispatch_event(target: picker["_i"], name: "change", data: { "value" => "2026-06-02T00:00:00+00:00" })

      refute dialog_stack_contains?(sent, picker["_i"])
      assert control_value_updated?(sent, date_display["_i"], "2026-06-02")

      sent.clear
      page.dispatch_event(target: choose_date["_i"], name: "click", data: nil)
      reopened_picker = find_last_patch_control(sent, "_c" => "DatePicker")

      refute_nil reopened_picker
      assert_equal true, reopened_picker["open"]
      assert dialog_stack_contains?(sent, reopened_picker["_i"])

      sent.clear
      page.apply_client_update(reopened_picker["_i"], "open" => false, "value" => "2026-06-02T00:00:00+00:00")
      page.dispatch_event(target: reopened_picker["_i"], name: "dismiss", data: nil)

      refute dialog_stack_contains?(sent, reopened_picker["_i"])

      sent.clear
      page.dispatch_event(target: save["_i"], name: "click", data: nil)

      assert_equal "2026-06-02", record.public_send("publish_on")
      assert dialog_stack_empty?(sent)

      edit = find_latest_data_cell_by_icon_tooltip(sent, "Edit")
      refute_nil edit

      sent.clear
      page.dispatch_event(target: edit["_i"], name: "tap", data: nil)
      reopened_form_dialog = find_last_patch_control(sent, "_c" => "AlertDialog")

      refute_nil reopened_form_dialog
      assert_equal true, reopened_form_dialog["open"]
    end
  end

  private

  def install_generated_scaffold(model_name, attributes)
    model_class = stub_model(model_name)
    component_source = Ruflet::Rails::InstallSupport.scaffold_component_template(model_name: model_name, attributes: attributes)
    Object.class_eval(component_source.sub(/^require.*\n/, "").sub(/^require.*\n/, ""))
    yield model_class
  ensure
    component_name = "#{model_name}Component"
    Object.send(:remove_const, component_name) if Object.const_defined?(component_name)
    Object.send(:remove_const, model_name) if Object.const_defined?(model_name) && Object.const_get(model_name) == model_class
  end

  def stub_model(name)
    model = Class.new do
      class << self
        attr_accessor :records, :update_result
      end

      def self.limit(*)
        records || []
      end

      def self.all
        records || []
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, name)
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

      def destroy!
        @destroyed = true
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

  def find_last_patch_control(sent, criteria)
    sent.reverse_each do |(_action, payload)|
      found = find_patch_control(payload["patch"], criteria)
      return found if found
    end

    nil
  end

  def find_data_cell_by_icon_tooltip(value, tooltip)
    case value
    when Hash
      return value if value["_c"] == "DataCell" && find_patch_control(value["content"], "_c" => "Icon", "tooltip" => tooltip)

      value.each_value do |child|
        found = find_data_cell_by_icon_tooltip(child, tooltip)
        return found if found
      end
    when Array
      value.each do |child|
        found = find_data_cell_by_icon_tooltip(child, tooltip)
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

  def dialog_stack_contains?(sent, wire_id)
    sent.any? do |(_action, payload)|
      Array(payload["patch"]).any? do |op|
        next false unless op[2] == "controls" && op[3].is_a?(Array)

        control = find_patch_control(op[3], "_i" => wire_id)
        control && control["open"] != false
      end
    end
  end

  def dialog_stack_empty?(sent)
    sent.any? do |(_action, payload)|
      Array(payload["patch"]).any? do |op|
        (op[2] == "controls" && op[3] == []) ||
          (op[2] == "open" && op[3] == false) ||
          (op[2] == "controls" && op[3].is_a?(Array) && no_open_dialogs?(op[3])) ||
          (op[2] == "_dialogs" && op[3].is_a?(Hash) && (
            op[3]["controls"] == [] || no_open_dialogs?(op[3]["controls"])
          ))
      end
    end
  end

  def no_open_dialogs?(controls)
    Array(controls).none? do |control|
      control.is_a?(Hash) && control["_c"].to_s.end_with?("Dialog") && control["open"] != false
    end
  end

  def control_value_updated?(sent, wire_id, value)
    sent.any? do |(_action, payload)|
      payload["id"] == wire_id && Array(payload["patch"]).any? { |op| op[2] == "value" && op[3] == value }
    end
  end

  def find_latest_data_cell_by_icon_tooltip(sent, tooltip)
    sent.reverse_each do |(_action, payload)|
      found = find_data_cell_by_icon_tooltip(payload["patch"], tooltip)
      return found if found
    end

    nil
  end
end
