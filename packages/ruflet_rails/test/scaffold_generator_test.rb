# frozen_string_literal: true

require_relative "test_helper"

local_lib = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(local_lib) unless $LOAD_PATH.include?(local_lib)

require "rails/generators"
require "generators/ruflet/scaffold/scaffold_generator"

class RufletScaffoldGeneratorTest < Minitest::Test
  RailsGenerators = ::Rails::Generators

def test_generates_one_pure_config_component
  Dir.mktmpdir do |dir|
    capture_io do
      RailsGenerators.invoke("ruflet:scaffold", ["Post", "title:string", "body:text"], destination_root: dir)
    end

    refute File.exist?(File.join(dir, "app/views/ruflet/posts_view.rb")),
           "the scaffold must not generate a separate view file"

    src = File.read(File.join(dir, "app/views/ruflet/components/posts/post_component.rb"))

    assert_includes src, "class PostComponent < Ruflet::Rails::ResourceComponent"

    # Pure config: the only methods are the field configuration.
    assert_includes src, "def resource_fields"
    assert_includes src, "def display_fields"
    assert_includes src, "def form_fields"
    assert_includes src, '["title", "body"]'
    assert_includes src, '{ name: "title", type: :string }'
    assert_includes src, '{ name: "body", type: :text }'

    # The whole CRUD UI is inherited from the base, NOT generated.
    refute_includes src, "def render"
    refute_includes src, "def show"
    refute_includes src, "def open_form"
    refute_includes src, "def record_table"
    refute_includes src, "def open_delete"
    refute_includes src, "data_table("
    refute_includes src, "alert_dialog("
    refute_includes src, "text_field"
    refute_includes src, "date_picker("
    refute_includes src, "save_record"
    refute_includes src, "def display_value"

    # No legacy view / metadata leakage.
    refute_includes src, "Ruflet::Rails::ResourceView"
    refute_includes src, 'route "/posts"'
    refute_includes src, "def model_class"
    refute_includes src, "title:string"
    refute_includes src, "body:text"
    assert_silent_syntax src
    refute File.exist?(File.join(dir, "app/views/ruflet/components/application_component.rb"))
  end
end

def assert_silent_syntax(source)
  RubyVM::InstructionSequence.compile(source)
rescue SyntaxError => e
  flunk "generated code has a syntax error: #{e.message}"
end

def test_generated_component_is_valid_ruby_without_date_attributes
  component = Ruflet::Rails::InstallSupport.scaffold_component_template(
    model_name: "Product",
    attributes: ["name:string", "price:decimal", "description:text"]
  )
  assert_includes component, "def form_fields"
  refute_includes component, "case field"
  assert_silent_syntax component
end

def test_form_fields_carry_attribute_types
  component = Ruflet::Rails::InstallSupport.scaffold_component_template(
    model_name: "Event",
    attributes: ["title:string", "count:integer", "active:boolean", "starts_on:date",
                 "starts_at:time", "window:daterange", "notes:text"]
  )
  assert_includes component, '{ name: "title", type: :string }'
  assert_includes component, '{ name: "count", type: :integer }'
  assert_includes component, '{ name: "active", type: :boolean }'
  assert_includes component, '{ name: "starts_on", type: :date }'
  assert_includes component, '{ name: "starts_at", type: :time }'
  assert_includes component, '{ name: "window", type: :daterange }'
  assert_includes component, '{ name: "notes", type: :text }'
  assert_silent_syntax component
end

def test_no_attribute_metadata_or_ui_leaks_into_generated_file
  src = Ruflet::Rails::InstallSupport.scaffold_component_template(
    model_name: "NewsArticle",
    attributes: ["headline:string", "published:boolean"]
  )
  assert_includes src, "class NewsArticleComponent < Ruflet::Rails::ResourceComponent"
  assert_includes src, '{ name: "headline", type: :string }'
  assert_includes src, '{ name: "published", type: :boolean }'
  refute_includes src, "headline:string"
  refute_includes src, "checkbox("
  refute_includes src, "text_field"
  refute_includes src, "Ruflet::Rails::ResourceView"
end

def test_base_form_stretches_inputs_to_the_dialog_width
  install_generated_scaffold("Stretchy", ["title:string"]) do |model_class|
    model_class.records = []
    sent = []
    page = Ruflet::Page.new(session_id: "s", client_details: { "route" => "/stretchies", "width" => 1280 },
                            sender: ->(a, p) { sent << [a, p] })
    StretchyComponent.render(page)
    new_button = find_patch_control(sent.last[1]["patch"], "_c" => "FilledButton")
    sent.clear
    page.dispatch_event(target: new_button["_i"], name: "click", data: nil)
    column = find_last_patch_control(sent, "_c" => "Column", "horizontal_alignment" => "stretch")
    refute_nil column, "the form content column should stretch its inputs to the dialog width"
  end
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
