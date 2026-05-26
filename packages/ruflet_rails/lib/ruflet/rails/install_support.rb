# frozen_string_literal: true

require "fileutils"
require "rbconfig"
require "active_support/core_ext/string/inflections"

module Ruflet
  module Rails
    module InstallSupport
      module_function

      def default_app_template(app_title:)
        template = <<~RUBY
          require "ruflet"
          require "ruflet_rails"

          Ruflet.run do |page|
            page.title = #{app_title.inspect}
            Ruflet::Rails.render(page)
          end
        RUBY
        template.gsub(/^    /, "  ")
      end

      def application_component_template
        template = <<~RUBY
          # frozen_string_literal: true

          # ApplicationComponent is the base class for all Ruflet UI components in
          # this Rails app.  It explicitly includes Ruflet::UI::SharedControlForwarders
          # so that every subclass has the full ruflet widget DSL available as
          # instance methods (text, column, row, container, safe_area, filled_button,
          # icon, data_table, alert_dialog, and every other ruflet widget).
          # This is the same DSL that ruflet studio uses — explicit, no Kernel magic.
          class ApplicationComponent
              include Ruflet::UI::SharedControlForwarders

              attr_reader :page

              def self.render(page, *args, **kwargs, &block)
                new(page).render(*args, **kwargs, &block)
              end

              def initialize(page)
                @page = page
              end

              private

              # Widget builder calls on this component delegate to Ruflet::DSL,
              # the same target used by the ruflet studio App and by Kernel.
              # Override in a subclass to scope builds to a local WidgetBuilder.
              def control_delegate
                Ruflet::DSL
              end

              def platform
                page.client_details["platform"].to_s
              end

              def desktop?
                %w[macos windows linux].include?(platform)
              end

              def web?
                platform == "web"
              end

              def mobile?
                !desktop? && !web?
              end

              def screen_width
                page.client_details["width"].to_f
              end

              # Returns true when the client is narrower than 600 logical pixels
              # (phones and small tablets), enabling compact list layouts.
              def compact?
                screen_width > 0 && screen_width < 600
              end
          end
        RUBY
        template.gsub(/^    /, "  ")
      end

      def application_component_path
        File.join("app", "views", "ruflet", "components", "application_component.rb")
      end

      def default_mobile_app_template(app_title:)
        default_app_template(app_title: app_title)
      end

      def scaffold_view_template(model_name:, attributes:)
        names = scaffold_names(model_name)
        attrs = Array(attributes).map { |field| normalize_scaffold_attribute(field) }.reject { |field| field[:name].empty? }
        attrs = [{ name: "name", type: "string" }] if attrs.empty?
        model_class = names[:class_name]
        component_class = "#{model_class}Component"
        title = names[:title]
        singular_title = names[:singular].humanize.titleize

        template = <<~RUBY
          # frozen_string_literal: true

          require "ostruct"
          require "ruflet_rails"

          # #{model_class}View is the Rails-backed Ruflet view for #{model_class}.
          # It acts as a thin controller: it fetches ActiveRecord data and delegates
          # all UI building to #{component_class}.  RufletView (and its included
          # Ruflet::UI::SharedControlForwarders) gives every view instance the full
          # ruflet widget DSL, matching the pattern used by ruflet studio.
          class #{model_class}View < RufletView
              route #{("/" + names[:plural]).inspect}

              # Entry point called by the ViewRouter on every route render.
              # Defaults to :index so the list is shown on first load.
              def render(action: :index, record: nil)
                public_send(action, record)
              end

              # ─── Actions ─────────────────────────────────────────────────────

              def index(_record = nil)
                records = model_class.order(created_at: :desc).limit(50)

                page.title = #{title.inspect}
                page.add(component.index(records: records), **component.index_view_options)
              end

              def show(record = nil)
                record ||= model_class.first
                return index unless record

                page.title = "#{singular_title} ##\{record.id}"
                page.add(component.show(record: record), **component.show_view_options)
              end

              def new(_record = nil)
                component.open_form_dialog(model_class.new, title: "New #{singular_title}")
              end

              def edit(record = nil)
                return index unless record

                component.open_form_dialog(record, title: "Edit #{singular_title}")
              end

              # Called by the component's Save button.
              # Returns true on success (dialog closes); false on validation failure
              # (dialog stays open so the user can fix errors).
              def update(record, attributes, dialog)
                if record.update(attributes)
                  close_dialog(dialog)
                  index
                  component.show_message("#{singular_title} saved successfully")
                  true
                else
                  component.show_errors(record)
                  false
                end
              end

              # Called by the component's Delete confirmation dialog.
              def destroy(record, dialog)
                record.destroy!
                close_dialog(dialog)
                index
                component.show_message("#{singular_title} deleted")
              rescue => e
                component.show_errors(
                  OpenStruct.new(errors: OpenStruct.new(full_messages: [e.message]))
                )
              end

              def close_dialog(dialog)
                page.update(dialog, open: false)
                page.close_dialog(dialog)
              end

              # ─── Model accessor ──────────────────────────────────────────────

              def model_class
                #{model_class}
              end

              private

              # The component is memoised per page session.  It receives self as
              # the controller so it can invoke index/show/edit/update/destroy.
              def component
                @component ||= #{component_class}.new(page, controller: self)
              end
          end
        RUBY
        template.gsub(/^    /, "  ")
      end

      def scaffold_component_template(model_name:, attributes:)
        names = scaffold_names(model_name)
        attrs = Array(attributes).map { |field| normalize_scaffold_attribute(field) }.reject { |field| field[:name].empty? }
        attrs = [{ name: "name", type: "string" }] if attrs.empty?
        form_locals = scaffold_form_locals(attrs)
        form_controls = scaffold_form_controls(attrs)
        form_attributes = scaffold_form_attributes(attrs)
        show_field_rows = attrs.map do |field|
          %(field_row(#{field[:name].humanize.inspect}, record.public_send(#{field[:name].inspect}).to_s))
        end.join(",\n                  ")
        table_column_controls = attrs.map { |field| %(data_column(#{field[:name].humanize.inspect})) }.join(",\n        ")
        table_cells = attrs.map do |field|
          %(data_cell(record.public_send(#{field[:name].inspect}).to_s, on_tap: ->(_e) { controller.show(record) }))
        end.join(",\n          ")
        primary_label = %(record.public_send(#{attrs.first[:name].inspect}).to_s)
        secondary_label = attrs[1] ? %(record.public_send(#{attrs[1][:name].inspect}).to_s) : "nil"
        model_class = names[:class_name]
        component_class = "#{model_class}Component"
        title = names[:title]
        singular_title = names[:singular].humanize.titleize

        template = <<~RUBY
          # frozen_string_literal: true

          require "ruflet_rails"

          # #{component_class} owns all UI for #{model_class} CRUD screens.
          # Every widget method (text, column, row, data_table, alert_dialog, …) is
          # inherited from ApplicationComponent via Ruflet::UI::SharedControlForwarders —
          # the exact same DSL ruflet studio uses.  No widget code is hardcoded here;
          # all controls are built through the shared ruflet DSL.
          class #{component_class} < ApplicationComponent
              attr_reader :controller

              def initialize(page, controller:)
                super(page)
                @controller = controller
              end

              # ─── Index ───────────────────────────────────────────────────────

              def index(records:)
                safe_area(
                  container(
                    expand: true,
                    padding: { left: 24, top: 16, right: 24, bottom: 24 },
                    content: column(
                      expand: true,
                      spacing: 16,
                      children: [
                        index_header,
                        compact? ? record_list(records) : record_table(records)
                      ]
                    )
                  ),
                  expand: true
                )
              end

              # ─── Show ────────────────────────────────────────────────────────

              def show(record:)
                safe_area(
                  container(
                    expand: true,
                    padding: { left: 24, top: 16, right: 24, bottom: 24 },
                    content: column(
                      expand: true,
                      spacing: 16,
                      children: [
                        column(
                          spacing: 8,
                          children: [
                            text("#{singular_title} ##\{record.id}", size: 24, weight: "bold"),
                            row(
                              alignment: "end",
                              children: [action_buttons(record)]
                            )
                          ]
                        ),
                        divider,
                        column(
                          spacing: 8,
                          children: [
                            #{show_field_rows}
                          ]
                        )
                      ]
                    )
                  ),
                  expand: true
                )
              end

              # ─── Form dialog ─────────────────────────────────────────────────

              def open_form_dialog(record, title:)
                __FORM_LOCALS__

                attributes = lambda do
                  {
                    __FORM_ATTRIBUTES__
                  }
                end

                dialog = nil
                closing = false
                dialog = alert_dialog(
                  open: false,
                  modal: true,
                  scrollable: true,
                  title: text(title),
                  content: container(
                    width: dialog_width,
                    content: column(
                      spacing: 8,
                      children: [
                        __FORM_CONTROLS__
                      ]
                    )
                  ),
                  actions: [
                    text_button(
                      content: text("Cancel"),
                      on_click: ->(_e) { controller.close_dialog(dialog) }
                    ),
                    filled_button(
                      content: text("Save"),
                      on_click: ->(_e) do
                        next if closing

                        closing = true
                        closing = false unless controller.update(record, attributes.call, dialog)
                      end
                    )
                  ],
                  actions_alignment: "end"
                )
                page.show_dialog(dialog)
              end

              # ─── Delete dialog ───────────────────────────────────────────────

              def open_delete_dialog(record)
                dialog = nil
                closing = false
                dialog = alert_dialog(
                  open: false,
                  modal: true,
                  title: text("Delete #{singular_title}?"),
                  content: text(
                    "Permanently remove #{singular_title} ##\{record.id}? " \
                    "This cannot be undone.",
                    no_wrap: false
                  ),
                  actions: [
                    text_button(
                      content: text("Cancel"),
                      on_click: ->(_e) { controller.close_dialog(dialog) }
                    ),
                    filled_button(
                      content: text("Delete"),
                      on_click: ->(_e) do
                        next if closing

                        closing = true
                        controller.destroy(record, dialog)
                      end
                    )
                  ],
                  actions_alignment: "end"
                )
                page.show_dialog(dialog)
              end

              # ─── Feedback helpers ────────────────────────────────────────────

              def show_errors(record)
                show_message(scaffold_error_message(record))
              end

              def show_message(message)
                page.snackbar = snackbar(text(message), open: true)
              end

              # ─── View options ────────────────────────────────────────────────

              def show_view_options
                back_appbar_options(
                  tooltip: "Back to #{title}",
                  on_click: ->(_e) { controller.index }
                )
              end

              def index_view_options
                return {} if page.route.to_s == "/"

                back_appbar_options(
                  tooltip: "Back",
                  on_click: ->(_e) { page.go("/") }
                )
              end

              # ─── Private widget builders ─────────────────────────────────────

              private

              def back_appbar_options(tooltip:, on_click:)
                {
                  appbar: app_bar(
                    leading: icon_button(
                      "arrow_back",
                      tooltip: tooltip,
                      on_click: on_click
                    )
                  )
                }
              end

              # Header row: title left, "New …" button right — studio pattern.
              def index_header
                row(
                  alignment: "spaceBetween",
                  vertical_alignment: "center",
                  children: [
                    container(
                      expand: true,
                      content: text(#{title.inspect}, size: 24, weight: "bold")
                    ),
                    filled_button(
                      content: text("New #{singular_title}"),
                      on_click: ->(_e) { controller.new }
                    )
                  ]
                )
              end

              # Desktop: horizontally scrollable data table with action icon columns.
              def record_table(records)
                row(
                  scroll: "auto",
                  children: [
                    data_table(
                      table_columns,
                      rows: records.map { |record| table_row(record) },
                      column_spacing: 24,
                      horizontal_margin: 12,
                      show_bottom_border: true
                    )
                  ]
                )
              end

              # Mobile / compact: list of tappable list_tile rows.
              def record_list(records)
                column(
                  spacing: 4,
                  children: records.map { |record| record_tile(record) }
                )
              end

              # One list_tile for a record (compact screens).
              def record_tile(record)
                primary_label = #{primary_label}
                secondary_label = #{secondary_label}

                list_tile(
                  title:    text(primary_label),
                  subtitle: secondary_label ? text(secondary_label) : nil,
                  trailing: row(
                    tight: true,
                    spacing: 0,
                    children: [
                      icon_button("edit",   tooltip: "Edit",   on_click: ->(_e) { controller.edit(record) }),
                      icon_button("delete", tooltip: "Delete", on_click: ->(_e) { open_delete_dialog(record) })
                    ]
                  ),
                  on_click: ->(_e) { controller.show(record) }
                )
              end

              # Data table column headers (desktop).
              def table_columns
                [
                  #{table_column_controls},
                  data_column("Actions"),
                  data_column(""),
                  data_column("")
                ]
              end

              # One data_row for a record (desktop).
              def table_row(record)
                data_row(
                  [
                    #{table_cells},
                    data_cell(icon("visibility", tooltip: "Show"),   on_tap: ->(_e) { controller.show(record) }),
                    data_cell(icon("edit",        tooltip: "Edit"),   on_tap: ->(_e) { controller.edit(record) }),
                    data_cell(icon("delete",      tooltip: "Delete"), on_tap: ->(_e) { open_delete_dialog(record) })
                  ]
                )
              end

              # Edit / delete icon buttons for the show-view header.
              def action_buttons(record)
                row(
                  spacing: 4,
                  children: [
                    icon_button("edit",   tooltip: "Edit #{singular_title}",   on_click: ->(_e) { controller.edit(record) }),
                    icon_button("delete", tooltip: "Delete #{singular_title}", on_click: ->(_e) { open_delete_dialog(record) })
                  ]
                )
              end

              # Label + value row used in the show view body.
              def field_row(label, value)
                row(
                  children: [
                    container(width: 140, content: text(label, weight: "bold")),
                    container(expand: true, content: text(value, no_wrap: false))
                  ]
                )
              end

              # Responsive dialog width: fills screen on mobile, capped at 520 on desktop.
              def dialog_width
                width = screen_width
                return 520 if width <= 0

                [[width - 64, 280].max, 520].min
              end

              def scaffold_picker_attribute(control, type)
                value = control.props["value"]
                return nil if value.to_s.empty?
                return value.to_s.split("T", 2).first if type == "date"

                value.to_s
              end

              def scaffold_date_value(value)
                return nil if value.nil?
                return value.iso8601 if value.respond_to?(:iso8601)
                return value.to_date.iso8601 if value.respond_to?(:to_date)

                value.to_s
              end

              def scaffold_picker_display_text(label, value)
                visible = value.to_s.empty? ? "Not selected" : value.to_s.split("T", 2).first
                "\#{label}: \#{visible}"
              end

              def scaffold_error_message(record)
                messages = record.errors.full_messages
                messages.respond_to?(:to_sentence) ? messages.to_sentence : messages.join(", ")
              end

              def scaffold_association_label(record)
                return record.name.to_s if record.respond_to?(:name)
                return record.title.to_s if record.respond_to?(:title)

                record.to_s
              end
          end
        RUBY
        template = template.gsub(/^    /, "  ")
        template.gsub!(/^[ \t]*__FORM_LOCALS__$/, indent_lines(form_locals, 4))
        template.gsub!(/^[ \t]*__FORM_ATTRIBUTES__$/, indent_lines(form_attributes, 8))
        template.gsub!(/^[ \t]*__FORM_CONTROLS__$/, indent_lines(form_controls, 12))
        template
      end

      def scaffold_form_locals(attrs)
        attrs.map { |field| scaffold_form_local(field) }.join("\n\n")
      end

      def scaffold_form_controls(attrs)
        attrs.map { |field| scaffold_form_control_expression(field) }.join(",\n")
      end

      def scaffold_form_attributes(attrs)
        attrs.map { |field| scaffold_form_attribute_expression(field) }.join(",\n")
      end

      def scaffold_form_local(field)
        name = field[:name]
        type = field[:type].to_s
        label = name.humanize
        control = scaffold_form_control_name(field)

        case type
        when "association", "references", "belongs_to"
          model = "#{control}_model"
          options = "#{control}_options"
          class_name = (field[:class_name] || name.sub(/_id\z/, "").camelize).inspect
          <<~RUBY.chomp
            #{model} = #{class_name}.safe_constantize
            #{options} = #{model}&.respond_to?(:all) ? #{model}.all.map { |item| dropdown_option(item.id.to_s, text: scaffold_association_label(item)) } : []
            #{control} = dropdown(#{options}, value: record.public_send(#{name.inspect}).to_s, label: #{label.inspect}, width: dialog_width)
          RUBY
        when "boolean"
          %(#{control} = checkbox(label: #{label.inspect}, value: !!record.public_send(#{name.inspect})))
        when "integer", "float", "decimal"
          %(#{control} = text_field(value: record.public_send(#{name.inspect}).to_s, label: #{label.inspect}, keyboard_type: "number", width: dialog_width))
        when "text"
          %(#{control} = text_field(value: record.public_send(#{name.inspect}).to_s, label: #{label.inspect}, multiline: true, min_lines: 3, width: dialog_width))
        when "date", "datetime", "timestamp", "time"
          picker = control
          display = "#{control}_display"
          picker_value = type == "time" ? %(record.public_send(#{name.inspect}).respond_to?(:strftime) ? record.public_send(#{name.inspect}).strftime("%H:%M") : record.public_send(#{name.inspect}).to_s) : %(scaffold_date_value(record.public_send(#{name.inspect})))
          picker_builder = type == "time" ? "time_picker" : "date_picker"
          <<~RUBY.chomp
            #{picker} = #{picker_builder}(value: #{picker_value}, help_text: #{label.inspect}, open: false)
            #{display} = text(scaffold_picker_display_text(#{label.inspect}, #{picker}.props["value"]))
            #{picker}.on(:change) do |event|
              page.update(event.control, open: false)
              page.close_dialog(event.control)
              page.update(#{display}, value: scaffold_picker_display_text(#{label.inspect}, event.control.props["value"]))
            end
            #{picker}.on(:dismiss) do |event|
              page.update(event.control, open: false)
              page.close_dialog(event.control)
            end
          RUBY
        else
          %(#{control} = text_field(value: record.public_send(#{name.inspect}).to_s, label: #{label.inspect}, width: dialog_width))
        end
      end

      def scaffold_form_control_expression(field)
        control = scaffold_form_control_name(field)
        type = field[:type].to_s
        return control unless %w[date datetime timestamp time].include?(type)

        label = field[:name].humanize
        display = "#{control}_display"
        <<~RUBY.chomp
          column(
            spacing: 6,
            width: dialog_width,
            children: [
              #{display},
              outlined_button(
                content: text("Choose #{label}"),
                width: dialog_width,
                on_click: ->(_e) { page.show_dialog(#{control}) }
              )
            ]
          )
        RUBY
      end

      def scaffold_form_attribute_expression(field)
        name = field[:name]
        type = field[:type].to_s
        control = scaffold_form_control_name(field)

        value =
          case type
          when "boolean"
            "!!#{control}.props[\"value\"]"
          when "date"
            "scaffold_picker_attribute(#{control}, \"date\")"
          when "datetime", "timestamp", "time"
            "scaffold_picker_attribute(#{control}, #{type.inspect})"
          when "association", "references", "belongs_to"
            "#{control}.props[\"value\"].to_s.empty? ? nil : #{control}.props[\"value\"]"
          else
            "#{control}.props[\"value\"].to_s"
          end

        "#{name.inspect} => #{value}"
      end

      def scaffold_form_control_name(field)
        "#{field[:name].gsub(/[^a-zA-Z0-9_]/, '_')}_control"
      end

      def indent_lines(text, spaces)
        prefix = " " * spaces
        text.lines(chomp: true).map { |line| line.empty? ? line : "#{prefix}#{line}" }.join("\n")
      end

      def scaffold_names(model_name)
        raw = model_name.to_s.strip
        class_name = raw.camelize
        singular = raw.underscore.singularize
        plural = singular.pluralize
        {
          class_name: class_name,
          singular: singular,
          plural: plural,
          title: plural.humanize.titleize
        }
      end

      def scaffold_view_path(model_name)
        names = scaffold_names(model_name)

        File.join("app", "views", "ruflet", names[:plural], "#{names[:plural]}_view.rb")
      end

      def form_view_path(model_name)
        names = scaffold_names(model_name)

        File.join("app", "views", "ruflet", "components", names[:plural], "#{names[:singular]}_form.rb")
      end

      def scaffold_component_path(model_name)
        names = scaffold_names(model_name)

        File.join("app", "views", "ruflet", "components", names[:plural], "#{names[:singular]}_component.rb")
      end

      def form_view_template(model_name:, attributes:)
        names = scaffold_names(model_name)
        attrs = normalized_form_attributes(attributes)
        fields_literal = attrs.map { |field| scaffold_field_literal(field) }.join(", ")
        model_class = names[:class_name]
        singular_title = names[:singular].humanize.titleize

        <<~RUBY
          # frozen_string_literal: true

          require "ruflet_rails"

          class #{model_class}Form < ApplicationComponent
              include Ruflet::Rails::FormHelpers

              def render(record:, title: nil, on_save: nil, on_cancel: nil)
                title ||= record.persisted? ? "Edit #{singular_title}" : "New #{singular_title}"
                fields = ruflet_form_bindings(record, form_fields)

                column(
                  expand: true,
                  spacing: 12,
                  children: [
                    text(title, size: 24, weight: "bold"),
                    column(spacing: 8, children: ruflet_form_controls(fields)),
                    row(
                      spacing: 8,
                      children: [
                        outlined_button(
                          content: text("Cancel"),
                          on_click: ->(_e) { on_cancel ? on_cancel.call(page, record) : nil }
                        ),
                        filled_button(
                          content: text(record.persisted? ? "Update #{singular_title}" : "Create #{singular_title}"),
                          on_click: ->(_e) { save(record, fields, on_save: on_save) }
                        )
                      ]
                    )
                  ]
                )
              end

              def save(record, fields, on_save: nil)
                if record.update(ruflet_form_attributes(fields, form_fields))
                  on_save ? on_save.call(page, record) : record
                else
                  ruflet_show_errors(record)
                  false
                end
              end

              def form_fields
                [#{fields_literal}]
              end
          end
        RUBY
      end

      def normalized_form_attributes(attributes)
        attrs = Array(attributes).map { |field| normalize_scaffold_attribute(field) }.reject { |field| field[:name].empty? }
        attrs.empty? ? [{ name: "name", type: "string" }] : attrs
      end

      def attributes_from_model(model_class)
        return [] unless model_class.respond_to?(:columns)

        model_class.columns.reject { |column|
          %w[id created_at updated_at].include?(column.name)
        }.map { |column| "#{column.name}:#{column.type}" }
      end

      def scaffold_field_literal(field)
        parts = [
          "name: #{field[:name].inspect}",
          "type: #{field[:type].inspect}"
        ]
        parts << "class_name: #{field[:class_name].inspect}" if field[:class_name]
        "{ #{parts.join(', ')} }"
      end

      def normalize_scaffold_attribute(value)
        raw = value.to_s.strip
        name, type = raw.split(":", 2)
        name = name.to_s.underscore.gsub(/[^a-z0-9_]/, "")
        type = type.to_s.strip
        type = "string" if type.empty?
        name = "#{name}_id" if %w[references belongs_to association].include?(type) && !name.end_with?("_id")
        association = association_class_name_for(name, type)
        {
          name: name,
          type: association ? "association" : type
        }.tap do |field|
          field[:class_name] = association if association
        end
      end

      def association_class_name_for(name, type)
        return name.sub(/_id\z/, "").camelize if name.end_with?("_id")
        return name.camelize if %w[references belongs_to association].include?(type)

        nil
      end

      def default_ruflet_yaml(app_name:)
        <<~YAML
          app:
            name: #{app_name}
            backend_url: #{default_backend_url}

          services: []

          assets:
            splash_screen: assets/splash.png
            icon_launcher: assets/icon.png
        YAML
      end

      def default_backend_url
        "http://localhost:3000"
      end

      def host_desktop_platform
        host_os = RbConfig::CONFIG["host_os"]
        return "macos" if host_os.match?(/darwin/i)
        return "linux" if host_os.match?(/linux/i)
        return "windows" if host_os.match?(/mswin|mingw|cygwin/i)

        nil
      end

      def normalize_build_platform(platform)
        value = platform.to_s.strip.downcase
        return host_desktop_platform if value == "desktop"

        value
      end

      def build_args_for_platform(platform)
        normalized = normalize_build_platform(platform)
        return [] if normalized.to_s.empty?

        args = [normalized]
        args += ["--base-href", web_base_href] if normalized == "web"
        args
      end

      def default_entrypoint_path
        File.join("app", "views", "ruflet", "main.rb")
      end

      def route_snippet(entrypoint: default_entrypoint_path, mount_path: "/ws", helper: "app")
        %(mount Ruflet::Rails.#{helper}(Rails.root.join("#{entrypoint}")), at: "#{mount_path}")
      end

      def default_web_public_path
        "app"
      end

      def web_base_href(public_path = default_web_public_path)
        normalized = public_path.to_s.strip.gsub(%r{\A/+|/+\z}, "")
        normalized.empty? ? "/" : "/#{normalized}/"
      end

      def publish_web_build(root, public_path: default_web_public_path)
        publish_web_client(root, source: File.join(root, "build", "web"), public_path: public_path)
      end

      def publish_prebuilt_web_client(root, platform: host_desktop_platform, public_path: default_web_public_path)
        source = prebuilt_web_client_path(platform: platform)
        return false unless source

        publish_web_client(root, source: source, public_path: public_path)
      end

      def prebuilt_web_client_path(platform: host_desktop_platform)
        return nil if platform.to_s.empty?

        source = File.join(prebuilt_client_cache_root(platform: platform), "web")
        return nil unless Dir.exist?(source)
        return nil unless File.file?(File.join(source, "index.html"))

        source
      end

      def prebuilt_client_cache_root(platform: host_desktop_platform)
        require "ruflet/cli"

        if Ruflet::CLI.respond_to?(:client_cache_root_for, true)
          Ruflet::CLI.send(:client_cache_root_for, platform)
        else
          File.join(Dir.home, ".ruflet", "client", Ruflet::VERSION, platform.to_s)
        end
      end

      def publish_web_client(root, source:, public_path: default_web_public_path)
        return false unless Dir.exist?(source)
        return false unless File.file?(File.join(source, "index.html"))

        target = File.join(root, "public", public_path.to_s.gsub(%r{\A/+|/+\z}, ""))
        FileUtils.rm_rf(target)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp_r(source, target)
        rewrite_web_base_href(target, public_path: public_path)
        true
      end

      def rewrite_web_base_href(target, public_path:)
        index_path = File.join(target, "index.html")
        return unless File.file?(index_path)

        content = File.read(index_path)
        base_href = web_base_href(public_path)
        updated =
          if content.match?(%r{<base\s+href=["'][^"']*["']\s*/?>}i)
            content.sub(%r{<base\s+href=["'][^"']*["']\s*/?>}i, %(<base href="#{base_href}">))
          else
            content.sub(%r{<head([^>]*)>}i, %(<head\\1>\n  <base href="#{base_href}">))
          end
        File.write(index_path, updated)
      end

      def install_next_steps(target:, entrypoint:, client:, web_published:, mount_path: "/ws")
        web_path = default_web_public_path
        lines = [
          "Ruflet Rails installed.",
          "Generated entrypoint: #{entrypoint}",
          "Mounted websocket: #{mount_path}",
          "Next steps:",
          "  1. Start Rails: bin/rails server",
          "  2. Open the Ruflet web client: /#{web_path}/"
        ]

        if web_published
          lines << "Web client copied to public/#{web_path}."
        elsif target.to_s == "ruflet" || %w[web all].include?(client.to_s)
          lines += [
            "Web client was not copied because no built/prebuilt web index.html was found.",
            "To download the prebuilt client from GitHub: bin/rails ruflet:update[web]",
            "To build the WASM web client yourself, install the ruflet CLI globally first:",
            "  gem install ruflet",
            "Then build and copy build/web into public/#{web_path}:",
            "  bin/rails ruflet:build[web]"
          ]
        end

        if %w[desktop all].include?(client.to_s)
          lines += [
            "Desktop clients are server-driven and connect to this Rails app.",
            "To download the prebuilt desktop client: bin/rails ruflet:update[desktop]",
            "To build the host desktop client: bin/rails ruflet:build[desktop]"
          ]
        end

        lines
      end
    end
  end
end
