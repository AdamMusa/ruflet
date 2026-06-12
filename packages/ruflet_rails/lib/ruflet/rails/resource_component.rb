# frozen_string_literal: true

require "date"
require "time"
require "active_model"
require "active_support/core_ext/string/inflections"

module Ruflet
  module Rails
    # Base class for a Ruflet CRUD resource.
    #
    # A subclass holds only the app-specific surface — the UI (render/show) and
    # the field configuration (resource_fields/display_fields/display_value) —
    # while everything generic lives here: routing, model resolution, record
    # loading, persistence (save/destroy), navigation, dialog management and the
    # date/time picker helpers.
    #
    # It is mounted straight from config/routes.rb; the route path is declared
    # there, never inside the component:
    #
    #   mount Ruflet::Rails.web_app(view: "ProductComponent"), at: "/products"
    #
    # web_app(view:) calls `.render(page)` on the class, which is why the class
    # method below is the entrypoint. The model is inferred from the class name
    # (ProductComponent -> Product); override `model_class` to customize.
    class ResourceComponent
      include Ruflet::UI::SharedControlForwarders

      attr_reader :page, :controller

      class << self
        # Entrypoint used by web_app(view: "...") on each new session.
        def render(page, *_args)
          new(page).render_index
        end

        # Declare or read the managed model: `model Product` or inferred from
        # the component class name.
        def model(value = nil)
          @model_class = value if value
          @model_class || inferred_model_class
        end

        # Declare or read the plural resource title shown on the index screen.
        def title(value = nil)
          @resource_title = value if value
          @resource_title || (model_name ? model_name.plural.humanize.titleize : "Resources")
        end

        def singular_title
          model_name ? model_name.human.titleize : "Record"
        end

        private

        def inferred_model_class
          base = name.to_s.split("::").last.to_s.sub(/Component\z/, "")
          base.empty? ? nil : base.safe_constantize
        end

        def model_name
          klass = model
          klass.respond_to?(:model_name) ? klass.model_name : nil
        rescue StandardError
          nil
        end
      end

      def initialize(page, controller: nil)
        @page = page
        @controller = controller
      end

      # --- Resource configuration (override in the generated subclass) --------

      def model_class
        self.class.model
      end

      def resource_title
        self.class.title
      end

      def singular_title
        model_class.respond_to?(:model_name) ? model_class.model_name.human.titleize : self.class.singular_title
      end

      # Fields rendered on the detail (show) screen. The generated subclass
      # overrides this with the scaffolded attributes; the default falls back to
      # the model's own attribute names.
      def resource_fields
        default_resource_fields
      end

      # Columns rendered in the index table / list tiles.
      def display_fields
        resource_fields
      end

      # The form inputs, as a declarative spec: each entry is a field name and
      # type. The default is inferred from the model's columns; the generated
      # subclass overrides it. Types: :string, :text, :integer, :decimal,
      # :float, :boolean, :date, :datetime, :time, :daterange.
      def form_fields
        default_form_fields
      end

      # Formats a single field for display. Dates and times render as ISO
      # strings; override for custom rendering.
      def display_value(record, field)
        value = record.public_send(field)
        case value
        when Date then value.iso8601
        when Time, DateTime then value.iso8601
        else value.to_s
        end
      rescue StandardError
        ""
      end

      # --- Generic CRUD UI (override any of these to customize) ---------------

      def render
        safe_area(
          container(
            expand: true,
            padding: { left: 24, top: 16, right: 24, bottom: 24 },
            content: column(
              expand: true,
              spacing: 16,
              children: [index_header, compact? ? record_list(records) : record_table(records)]
            )
          ),
          expand: true
        )
      end

      def show(record)
        safe_area(
          container(
            expand: true,
            padding: { left: 24, top: 16, right: 24, bottom: 24 },
            content: column(
              expand: true,
              spacing: 16,
              children: [
                show_header(record),
                column(
                  spacing: 8,
                  children: resource_fields.map { |field| field_row(field.humanize, display_value(record, field)) }
                )
              ]
            )
          ),
          expand: true
        )
      end

      # The create/edit dialog, rendered from `form_fields`.
      def open_form(record)
        inputs = form_fields.map { |spec| build_form_input(record, normalize_field_spec(spec)) }

        attributes = lambda do
          inputs.each_with_object({}) { |input, attrs| attrs[input.name] = input.value.call }
        end

        dialog = nil
        dialog = alert_dialog(
          open: false,
          modal: true,
          scrollable: true,
          title: text(record.persisted? ? "Edit #{singular_title}" : "New #{singular_title}"),
          content: container(
            width: dialog_width,
            content: column(spacing: 8, horizontal_alignment: "stretch", children: inputs.map(&:control))
          ),
          actions: [
            text_button(content: text("Cancel"), on_click: ->(_event) { close_dialog(dialog) }),
            filled_button(content: text("Save"), on_click: ->(_event) { save_record(record, attributes.call, dialog) })
          ],
          actions_alignment: "end"
        )
        open_dialog(dialog)
      end

      # --- Record loading & persistence --------------------------------------

      def records
        scope = model_class.respond_to?(:limit) ? model_class.limit(50) : model_class.all
        scope.respond_to?(:limit) ? scope.limit(50) : scope.to_a.first(50)
      end

      def render_index
        page.title = resource_title
        page.views = []
        page.add(render)
      end

      def render_show(record)
        page.views = []
        page.add(show(record))
        page.update
      end

      def show_record(record)
        render_show(record)
      end

      def save_record(record, attributes, dialog)
        if record.update(attributes)
          close_dialog(dialog)
          render_index
          show_snackbar("#{singular_title} saved")
        else
          show_errors(record)
        end
      end

      def destroy_record(record, dialog)
        record.destroy!
        close_dialog(dialog)
        render_index
        show_snackbar("#{singular_title} deleted")
      rescue StandardError => e
        show_snackbar(e.message)
      end

      # --- Index labels -------------------------------------------------------

      def primary_label(record)
        field = display_fields.first
        field ? display_value(record, field) : "##{record_id(record)}"
      end

      def secondary_label(record)
        field = display_fields[1]
        field ? display_value(record, field) : nil
      end

      private

      # One built form input: the control to render, and a proc returning the
      # value to persist for its attribute.
      FormInput = Struct.new(:name, :control, :value, keyword_init: true)

      def default_resource_fields
        return [] unless model_class.respond_to?(:attribute_names)

        ignored = %w[id created_at updated_at]
        model_class.attribute_names.map(&:to_s) - ignored
      rescue StandardError
        []
      end

      def default_form_fields
        resource_fields.map { |field| { name: field.to_s, type: form_field_type(field) } }
      end

      def form_field_type(field)
        return :string unless model_class.respond_to?(:columns_hash)

        column = model_class.columns_hash[field.to_s]
        case column&.type
        when :text then :text
        when :integer then :integer
        when :decimal, :float then :decimal
        when :boolean then :boolean
        when :date then :date
        when :datetime, :timestamp then :datetime
        when :time then :time
        else :string
        end
      rescue StandardError
        :string
      end

      def normalize_field_spec(spec)
        return { name: spec.to_s, type: :string } unless spec.is_a?(Hash)

        { name: (spec[:name] || spec["name"]).to_s, type: (spec[:type] || spec["type"] || :string).to_sym }
      end

      # --- Generic CRUD UI internals -----------------------------------------

      def index_header
        row(
          alignment: "spaceBetween",
          vertical_alignment: "center",
          children: [
            container(expand: true, content: text(resource_title, size: 24, weight: "bold")),
            filled_button(content: text("New #{singular_title}"), on_click: ->(_event) { open_form(model_class.new) })
          ]
        )
      end

      def show_header(record)
        row(
          alignment: "spaceBetween",
          vertical_alignment: "center",
          children: [
            container(expand: true, content: text("#{singular_title} ##{record_id(record)}", size: 24, weight: "bold")),
            row(
              tight: true,
              spacing: 8,
              children: [
                outlined_button(content: text("Back"), on_click: ->(_event) { render_index }),
                filled_button(content: text("Edit"), on_click: ->(_event) { open_form(record) })
              ]
            )
          ]
        )
      end

      def record_table(items)
        row(
          scroll: "auto",
          children: [
            data_table(
              table_columns,
              rows: items.map { |record| table_row(record) },
              column_spacing: 24,
              horizontal_margin: 12,
              show_bottom_border: true
            )
          ]
        )
      end

      def table_columns
        display_fields.map { |field| data_column(field.humanize) } +
          [data_column("Actions"), data_column(""), data_column("")]
      end

      def table_row(record)
        data_row(
          display_fields.map { |field| data_cell(display_value(record, field), on_tap: ->(_event) { open_show(record) }) } +
            [
              data_cell(icon("visibility", tooltip: "Show"), on_tap: ->(_event) { open_show(record) }),
              data_cell(icon("edit", tooltip: "Edit"), on_tap: ->(_event) { open_form(record) }),
              data_cell(icon("delete", tooltip: "Delete"), on_tap: ->(_event) { open_delete(record) })
            ]
        )
      end

      def record_list(items)
        column(spacing: 4, children: items.map { |record| record_tile(record) })
      end

      def record_tile(record)
        list_tile(
          title: text(primary_label(record)),
          subtitle: secondary_label(record) ? text(secondary_label(record)) : nil,
          trailing: row(
            tight: true,
            spacing: 0,
            children: [
              icon_button("edit", tooltip: "Edit", on_click: ->(_event) { open_form(record) }),
              icon_button("delete", tooltip: "Delete", on_click: ->(_event) { open_delete(record) })
            ]
          ),
          on_click: ->(_event) { open_show(record) }
        )
      end

      def field_row(label, value)
        row(
          children: [
            container(width: 140, content: text(label, weight: "bold")),
            container(expand: true, content: text(value, no_wrap: false))
          ]
        )
      end

      def open_show(record)
        show_record(record)
      end

      def open_delete(record)
        dialog = nil
        dialog = alert_dialog(
          open: false,
          modal: true,
          title: text("Delete #{singular_title}?"),
          content: text("Permanently remove #{singular_title} ##{record_id(record)}?", no_wrap: false),
          actions: [
            text_button(content: text("Cancel"), on_click: ->(_event) { close_dialog(dialog) }),
            filled_button(content: text("Delete"), on_click: ->(_event) { destroy_record(record, dialog) })
          ],
          actions_alignment: "end"
        )
        open_dialog(dialog)
      end

      # --- Form input builders, one per field type ---------------------------

      def build_form_input(record, spec)
        name = spec[:name]
        current = record.public_send(name)

        case spec[:type]
        when :boolean
          control = checkbox(value: !!current, label: name.humanize)
          FormInput.new(name: name, control: control, value: -> { !!control.value })
        when :date
          build_picker_input(name, date_picker_value(current), :date)
        when :datetime, :time
          build_picker_input(name, time_picker_value(current), :time)
        when :daterange
          build_range_input(name, current)
        else
          build_text_input(name, current, spec[:type])
        end
      end

      def build_text_input(name, current, type)
        props = { value: current.to_s, label: name.humanize }
        if type == :text
          props[:multiline] = true
          props[:min_lines] = 3
        elsif %i[integer decimal float].include?(type)
          props[:keyboard_type] = "number"
        end
        control = text_field(**props)
        FormInput.new(name: name, control: control, value: -> { control.value.to_s })
      end

      def build_picker_input(name, initial, kind)
        display = text(kind == :date ? date_display_value(initial) : time_display_value(initial))
        control =
          if kind == :date
            date_picker(value: initial, help_text: name.humanize, on_change: lambda do |_event|
              close_dialogs(picker_for(name))
              page.update(display, value: date_display_value(picker_for(name).value))
            end)
          else
            time_picker(value: initial, help_text: name.humanize, on_change: lambda do |_event|
              close_dialogs(picker_for(name))
              page.update(display, value: time_display_value(picker_for(name).value))
            end)
          end
        register_picker(name, control)
        field = picker_field(name, display, control)
        value = kind == :date ? -> { control.value.to_s.split("T", 2).first } : -> { control.value.to_s }
        FormInput.new(name: name, control: field, value: value)
      end

      def build_range_input(name, current)
        start_value, end_value = date_range_picker_values(current)
        display = text(date_range_display_value(start_value, end_value))
        control = date_range_picker(start_value: start_value, end_value: end_value, help_text: name.humanize,
                                    on_change: lambda do |_event|
                                      close_dialogs(picker_for(name))
                                      ctrl = picker_for(name)
                                      page.update(display, value: date_range_display_value(ctrl.start_value, ctrl.end_value))
                                    end)
        register_picker(name, control)
        field = picker_field(name, display, control)
        value = lambda do
          Range.new(Date.parse(control.start_value.to_s), Date.parse(control.end_value.to_s))
        end
        FormInput.new(name: name, control: field, value: value)
      end

      def picker_field(name, display, control)
        column(
          spacing: 6,
          children: [
            text(name.humanize),
            row(
              spacing: 8,
              children: [
                container(expand: true, content: display),
                outlined_button(content: text("Choose #{name.humanize}"), on_click: ->(_event) { open_dialog(control) })
              ]
            )
          ]
        )
      end

      def register_picker(name, control)
        (@form_pickers ||= {})[name] = control
      end

      def picker_for(name)
        (@form_pickers ||= {})[name]
      end

      def control_delegate
        Ruflet::DSL
      end

      # --- Layout helpers shared by every resource UI ------------------------

      def compact?
        width = page.client_details["width"].to_f
        width > 0 && width < 600
      end

      def dialog_width
        width = page.client_details["width"].to_f
        return 520 if width <= 0

        [[width - 64, 280].max, 520].min
      end

      def record_id(record)
        record.respond_to?(:id) ? record.id : nil
      end

      def show_errors(record)
        show_snackbar(error_message(record))
      end

      def show_snackbar(message)
        page.snackbar = snackbar(text(message), open: true)
      end

      def error_message(record)
        messages = record.errors.full_messages
        messages.respond_to?(:to_sentence) ? messages.to_sentence : messages.join(", ")
      end

      # --- Dialog management --------------------------------------------------

      def open_dialog(dialog)
        prune_closed_dialogs
        return open_primary_dialog(dialog) if primary_dialog?(dialog) && !latest_stack_dialog

        preserve_rendered_open_dialog_state
        page.show_dialog(dialog)
        dialog
      end

      def close_dialog(dialog)
        close_open_dialogs_above(dialog)
        close_tracked_dialog(dialog)
      end

      def close_dialogs(*dialogs)
        dialogs.flatten.compact.each do |dialog|
          close_tracked_dialog(dialog)
        end
      end

      def date_picker_value(value, fallback: Date.today)
        return value.to_date.iso8601 if value.respond_to?(:to_date)
        return fallback.iso8601 if value.to_s.empty?

        Date.parse(value.to_s).iso8601
      rescue ArgumentError
        fallback.iso8601
      end

      def datetime_picker_value(value, fallback: Time.now)
        return value.iso8601 if value.respond_to?(:iso8601)
        return fallback.iso8601 if value.to_s.empty?

        Time.parse(value.to_s).iso8601
      rescue ArgumentError
        fallback.iso8601
      end

      def time_picker_value(value)
        return value.strftime("%H:%M") if value.respond_to?(:strftime)

        value.to_s
      end

      def date_range_picker_values(value)
        if value.respond_to?(:begin) && value.respond_to?(:end)
          return [date_picker_value(value.begin), date_picker_value(value.end)]
        end
        if value.respond_to?(:to_a) && value.to_a.length >= 2
          first, last = value.to_a.first(2)
          return [date_picker_value(first), date_picker_value(last)]
        end

        raw = value.to_s.strip.gsub(/\A[\[(]|[\])]\z/, "")
        start_value, end_value =
          if raw.include?("...")
            raw.split("...", 2)
          elsif raw.include?("..")
            raw.split("..", 2)
          else
            raw.split(",", 2)
          end
        [date_picker_value(start_value), date_picker_value(end_value || start_value)]
      end

      def date_display_value(value)
        visible = value.to_s.split("T", 2).first
        visible.empty? ? "Not selected" : visible
      end

      def date_range_display_value(start_value, end_value)
        "#{date_display_value(start_value)} - #{date_display_value(end_value)}"
      end

      def time_display_value(value)
        visible = value.to_s
        visible.empty? ? "Not selected" : visible
      end

      def close_open_dialogs_above(dialog)
        return false unless page.respond_to?(:latest_open_dialog, true)

        while (latest = page.__send__(:latest_open_dialog)) && !latest.equal?(dialog)
          close_tracked_dialog(latest)
        end
      rescue StandardError
        false
      end

      def close_tracked_dialog(dialog)
        return unless dialog

        close_dialog_stack_entry(dialog)
      end

      def close_dialog_stack_entry(dialog)
        return close_primary_dialog(dialog) if primary_dialog_slot?(dialog)

        unless page.respond_to?(:remove_dialog_tracking, true)
          page.close_dialog(dialog)
          return
        end

        page.update(dialog, open: false) if dialog.wire_id
        page.__send__(:remove_dialog_tracking, dialog)
        sync_dialogs_container
      end

      def sync_dialogs_container
        dialogs_container = page.instance_variable_get(:@dialogs_container) if page.instance_variable_defined?(:@dialogs_container)
        return page.update unless dialogs_container&.wire_id

        page.update(dialogs_container, controls: dialogs_container.props["controls"])
      end

      def open_primary_dialog(dialog)
        dialog.props["open"] = true
        page.dialog = dialog
        dialog
      end

      def close_primary_dialog(dialog)
        page.update(dialog, open: false) if dialog.wire_id
      end

      def primary_dialog_slot?(dialog)
        page.instance_variable_defined?(:@dialog) && page.instance_variable_get(:@dialog).equal?(dialog)
      end

      def latest_stack_dialog
        page.__send__(:latest_open_dialog) if page.respond_to?(:latest_open_dialog, true)
      end

      def primary_dialog?(dialog)
        dialog.type.to_s.tr("_", "").casecmp("alertdialog").zero?
      end

      def preserve_rendered_open_dialog_state
        tracked_dialogs.each do |dialog|
          next if dialog.props["open"] == false

          dialog.props["_open"] = true
        end
      end

      def tracked_dialogs
        dialogs = []
        dialogs << page.instance_variable_get(:@dialog) if page.instance_variable_defined?(:@dialog)
        dialogs.concat(Array(page.instance_variable_get(:@dialogs))) if page.instance_variable_defined?(:@dialogs)
        dialogs.compact.uniq
      end

      def prune_closed_dialogs
        return unless page.respond_to?(:remove_dialog_tracking, true)

        dialogs = page.instance_variable_get(:@dialogs) if page.instance_variable_defined?(:@dialogs)
        Array(dialogs).select { |dialog| dialog.props["open"] == false }.each do |dialog|
          page.__send__(:remove_dialog_tracking, dialog)
        end
      end

      # Methods not found on the component fall back to an optional controller,
      # kept for apps that still pair a component with a separate host object.
      def method_missing(name, *args, **kwargs, &block)
        return controller.__send__(name, *args, **kwargs, &block) if controller&.respond_to?(name, true)

        super
      end

      def respond_to_missing?(name, include_private = false)
        (controller&.respond_to?(name, true) || false) || super
      end
    end
  end
end
