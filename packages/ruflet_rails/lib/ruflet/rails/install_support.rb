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

          Ruflet::Rails.load_views(__dir__)

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
          # This is the same DSL that showcase uses — explicit, no Kernel magic.
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
              # the same target used by the showcase App and by Kernel.
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

      def model_names(model_name)
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

      def form_view_path(model_name)
        names = model_names(model_name)

        File.join("app", "views", "ruflet", "components", names[:plural], "#{names[:singular]}_form.rb")
      end

      def scaffold_view_path(model_name)
        names = model_names(model_name)

        File.join("app", "views", "ruflet", "#{names[:plural]}_view.rb")
      end

      def scaffold_component_path(model_name)
        names = model_names(model_name)

        File.join("app", "views", "ruflet", "components", names[:plural], "#{names[:singular]}_component.rb")
      end

      def scaffold_view_template(model_name:, attributes: [])
        names = model_names(model_name)
        model_class = names[:class_name]
        view_class = "#{model_class}View"
        component_class = "#{model_class}Component"
        title = names[:title]
        attrs = normalized_form_attributes(attributes)
        resource_fields = scaffold_resource_fields(attrs)
        display_fields = scaffold_display_fields(attrs)
        display_value_cases = scaffold_display_value_cases(attrs)

        template = <<~RUBY
          # frozen_string_literal: true

          require "ruflet_rails"
          require_relative "components/#{names[:plural]}/#{names[:singular]}_component"

          class #{view_class} < Ruflet::Rails::ResourceView
            route #{("/" + names[:plural]).inspect}

            def render
              page.title = resource_title
              render_index
            end

            private

            def model_class
              #{model_class}
            end

            def resource_title
              #{title.inspect}
            end

            def singular_title
              model_class.model_name.human.titleize
            end

            def records
              scope = model_class.respond_to?(:limit) ? model_class.limit(50) : model_class.all
              scope.respond_to?(:limit) ? scope.limit(50) : scope.to_a.first(50)
            end

            def render_index
              page.views = []
              page.add(component.render)
            end

            def render_show(record)
              page.views = []
              page.add(component.show(record))
              page.update
            end

            def component
              @component ||= #{component_class}.new(page, controller: self)
            end

            def show_record(record)
              render_show(record)
            end

            def save_record(record, attributes, dialog)
              if record.update(attributes)
                close_dialog(dialog)
                render_index
                show_snackbar("\#{singular_title} saved")
              else
                show_errors(record)
              end
            end

            def destroy_record(record, dialog)
              record.destroy!
              close_dialog(dialog)
              render_index
              show_snackbar("\#{singular_title} deleted")
            rescue StandardError => e
              show_snackbar(e.message)
            end

            def resource_fields
              #{resource_fields}
            end

            def display_fields
              #{display_fields}
            end

            def display_value(record, field)
              case field
              __DISPLAY_VALUE_CASES__
              else
                record.public_send(field).to_s
              end
            end

            def primary_label(record)
              field = display_fields.first
              field ? display_value(record, field) : "##\#{record_id(record)}"
            end

            def secondary_label(record)
              field = display_fields[1]
              field ? display_value(record, field) : nil
            end

          end
        RUBY
        template.gsub(/^[ \t]*__DISPLAY_VALUE_CASES__$/, display_value_cases)
      end

      def scaffold_component_template(model_name:, attributes: [])
        names = model_names(model_name)
        model_class = names[:class_name]
        component_class = "#{model_class}Component"
        attrs = normalized_form_attributes(attributes)
        control_locals = scaffold_control_locals(attrs)
        control_list = scaffold_control_list(attrs)
        attributes_hash = scaffold_attributes_hash(attrs)

        <<~RUBY
          # frozen_string_literal: true

          require "date"
          require "ruflet_rails"

          class #{component_class} < Ruflet::Rails::ResourceComponent
            def render
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

            private

            def show_header(record)
              row(
                alignment: "spaceBetween",
                vertical_alignment: "center",
                children: [
                  container(expand: true, content: text("\#{singular_title} ##\#{record_id(record)}", size: 24, weight: "bold")),
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

            def index_header
              row(
                alignment: "spaceBetween",
                vertical_alignment: "center",
                children: [
                  container(expand: true, content: text(resource_title, size: 24, weight: "bold")),
                  filled_button(content: text("New \#{singular_title}"), on_click: ->(_event) { open_form(model_class.new) })
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
              display_fields.map { |field| data_column(field.humanize) } + [
                data_column("Actions"),
                data_column(""),
                data_column("")
              ]
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

            def open_show(record)
              show_record(record)
            end

            def open_form(record)
              #{control_locals}

              attributes = lambda do
                {
                  #{attributes_hash}
                }
              end

              dialog  = nil
              dialog  = alert_dialog(
                open: false,
                modal: true,
                scrollable: true,
                title: text(record.persisted? ? "Edit \#{singular_title}" : "New \#{singular_title}"),
                content: container(
                  width: dialog_width,
                  content: column(
                    spacing: 8,
                    children: [
                      #{control_list}
                    ]
                  )
                ),
                actions: [
                  text_button(content: text("Cancel"), on_click: ->(_event) { close_dialog(dialog) }),
                  filled_button(content: text("Save"), on_click: ->(_event) {
                    save_record(record, attributes.call, dialog)
                  })
                ],
                actions_alignment: "end"
              )
              open_dialog(dialog)
            end

            def open_delete(record)
              dialog = nil
              dialog = alert_dialog(
                open: false,
                modal: true,
                title: text("Delete \#{singular_title}?"),
                content: text("Permanently remove \#{singular_title} #\#{record_id(record)}?", no_wrap: false),
                actions: [
                  text_button(content: text("Cancel"), on_click: ->(_event) { close_dialog(dialog) }),
                  filled_button(content: text("Delete"), on_click: ->(_event) { destroy_record(record, dialog) })
                ],
                actions_alignment: "end"
              )
              open_dialog(dialog)
            end

            def field_row(label, value)
              row(
                children: [
                  container(width: 140, content: text(label, weight: "bold")),
                  container(expand: true, content: text(value, no_wrap: false))
                ]
              )
            end
          end
        RUBY
      end

      def scaffold_control_locals(attrs)
        attrs.map { |field| scaffold_control_local(field) }.join("\n    ")
      end

      def scaffold_resource_fields(attrs)
        attrs.map { |field| field[:name] }.inspect
      end

      def scaffold_display_fields(attrs)
        fields = attrs.reject { |field| field[:type].to_s == "text" }
        fields = attrs if fields.empty?
        fields.first(3).map { |field| field[:name] }.inspect
      end

      def scaffold_display_value_cases(attrs)
        attrs.filter_map do |field|
          next unless %w[date datetime timestamp time date_range daterange].include?(field[:type].to_s)

          name = field[:name]
          formatter =
            case field[:type].to_s
            when "time"
              "value.respond_to?(:strftime) ? value.strftime(\"%H:%M\") : value.to_s"
            when "date_range", "daterange"
              "value.respond_to?(:begin) && value.respond_to?(:end) ? \"\#{value.begin} - \#{value.end}\" : value.to_s"
            when "date"
              "value.respond_to?(:to_date) ? value.to_date.iso8601 : value.to_s"
            else
              "value.respond_to?(:iso8601) ? value.iso8601 : value.to_s"
            end
          [
            "    when #{name.inspect}",
            "      value = record.public_send(#{name.inspect})",
            "      #{formatter}"
          ].join("\n")
        end.join("\n")
      end

      def scaffold_control_list(attrs)
        attrs.map { |field| scaffold_control_view_name(field) }.join(",\n            ")
      end

      def scaffold_attributes_hash(attrs)
        attrs.map { |field| scaffold_attribute_pair(field) }.join(",\n        ")
      end

      def scaffold_control_local(field)
        name = field[:name]
        type = field[:type].to_s
        control = scaffold_control_name(field)
        label = name.humanize
        value = "record.public_send(#{name.inspect})"

        case type
        when "boolean"
          "#{control} = checkbox(label: #{label.inspect}, value: !!#{value})"
        when "date", "datetime", "timestamp"
          display_control = "#{control}_display"
          picker_value_helper = type == "date" ? "date_picker_value" : "datetime_picker_value"
          <<~RUBY.chomp
            #{control}_value = #{picker_value_helper}(#{value})
                #{display_control} = text(date_display_value(#{control}_value))
                #{control} = date_picker(
                  value: #{control}_value,
                  help_text: #{label.inspect},
                  on_change: ->(_event) do
                    close_dialogs(#{control})
                    page.update(#{display_control}, value: date_display_value(#{control}.props["value"]))
                  end
                )
                #{control}_field = column(
                  spacing: 6,
                  children: [
                    text(#{label.inspect}),
                    row(
                      spacing: 8,
                      children: [
                        container(expand: true, content: #{display_control}),
                        outlined_button(content: text("Choose #{label}"), on_click: ->(_event) { open_dialog(#{control}) })
                      ]
                    )
                  ]
                )
          RUBY
        when "time"
          display_control = "#{control}_display"
          <<~RUBY.chomp
            #{control}_value = time_picker_value(#{value})
                #{display_control} = text(time_display_value(#{control}_value))
                #{control} = time_picker(
                  value: #{control}_value,
                  help_text: #{label.inspect},
                  on_change: ->(_event) do
                    close_dialogs(#{control})
                    page.update(#{display_control}, value: time_display_value(#{control}.props["value"]))
                  end
                )
                #{control}_field = column(
                  spacing: 6,
                  children: [
                    text(#{label.inspect}),
                    row(
                      spacing: 8,
                      children: [
                        container(expand: true, content: #{display_control}),
                        outlined_button(content: text("Choose #{label}"), on_click: ->(_event) { open_dialog(#{control}) })
                      ]
                    )
                  ]
                )
          RUBY
        when "date_range", "daterange"
          display_control = "#{control}_display"
          <<~RUBY.chomp
            #{control}_start_value, #{control}_end_value = date_range_picker_values(#{value})
                #{display_control} = text(date_range_display_value(#{control}_start_value, #{control}_end_value))
                #{control} = date_range_picker(
                  start_value: #{control}_start_value,
                  end_value: #{control}_end_value,
                  help_text: #{label.inspect},
                  on_change: ->(_event) do
                    close_dialogs(#{control})
                    page.update(
                      #{display_control},
                      value: date_range_display_value(#{control}.props["start_value"], #{control}.props["end_value"])
                    )
                  end
                )
                #{control}_field = column(
                  spacing: 6,
                  children: [
                    text(#{label.inspect}),
                    row(
                      spacing: 8,
                      children: [
                        container(expand: true, content: #{display_control}),
                        outlined_button(content: text("Choose #{label}"), on_click: ->(_event) { open_dialog(#{control}) })
                      ]
                    )
                  ]
                )
          RUBY
        when "text"
          "#{control} = text_field(value: #{value}.to_s, label: #{label.inspect}, multiline: true, min_lines: 3)"
        when "integer", "float", "decimal"
          "#{control} = text_field(value: #{value}.to_s, label: #{label.inspect}, keyboard_type: \"number\")"
        else
          "#{control} = text_field(value: #{value}.to_s, label: #{label.inspect})"
        end
      end

      def scaffold_attribute_pair(field)
        name = field[:name]
        type = field[:type].to_s
        control = scaffold_control_name(field)
        value =
          case type
          when "boolean"
            "!!#{control}.props[\"value\"]"
          when "date"
            "#{control}.props[\"value\"].to_s.split(\"T\", 2).first"
          when "date_range", "daterange"
            "Range.new(Date.parse(#{control}.props[\"start_value\"].to_s), Date.parse(#{control}.props[\"end_value\"].to_s))"
          else
            "#{control}.props[\"value\"].to_s"
          end

        "#{name.inspect} => #{value}"
      end

      def scaffold_control_name(field)
        "#{field[:name].gsub(/[^a-zA-Z0-9_]/, '_')}_control"
      end

      def scaffold_control_view_name(field)
        control = scaffold_control_name(field)
        %w[date datetime timestamp time date_range daterange].include?(field[:type].to_s) ? "#{control}_field" : control
      end

      def form_view_template(model_name:, attributes:)
        names = model_names(model_name)
        attrs = normalized_form_attributes(attributes)
        fields_literal = attrs.map { |field| form_field_literal(field) }.join(", ")
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
                  show_errors(record)
                  false
                end
              end

              def form_fields
                [#{fields_literal}]
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
          end
        RUBY
      end

      def normalized_form_attributes(attributes)
        attrs = Array(attributes).map { |field| normalize_form_attribute(field) }.reject { |field| field[:name].empty? }
        attrs.empty? ? [{ name: "name", type: "string" }] : attrs
      end

      def attributes_from_model(model_class)
        return [] unless model_class.respond_to?(:columns)

        model_class.columns.reject { |column|
          %w[id created_at updated_at].include?(column.name)
        }.map { |column| "#{column.name}:#{column.type}" }
      end

      def form_field_literal(field)
        parts = [
          "name: #{field[:name].inspect}",
          "type: #{field[:type].inspect}"
        ]
        parts << "class_name: #{field[:class_name].inspect}" if field[:class_name]
        "{ #{parts.join(', ')} }"
      end

      def normalize_form_attribute(value)
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

      def desktop_initializer_path
        File.join("config", "initializers", "ruflet_desktop.rb")
      end

      def desktop_initializer_template
        <<~RUBY
          # frozen_string_literal: true

          # Set this to true when you intentionally want the Rails server process to
          # launch the server-driven Ruflet desktop client.
          Rails.application.configure do
            config.x.ruflet_rails.desktop = false
          end
        RUBY
      end

      def ruby_desktop_flag_bootstrap
        <<~RUBY
          # ruflet_rails desktop flag
          ruflet_rails_desktop = ARGV.include?("--desktop")
          ruflet_rails_command = ARGV.find { |value| !value.to_s.start_with?("-") }
          if ruflet_rails_desktop && %w[server s].include?(ruflet_rails_command.to_s)
            ENV["RUFLET_RAILS_DESKTOP"] = "true"
            ENV["RUFLET_RAILS_DESKTOP_SERVER"] = "true"
          end
          ARGV.delete("--desktop")

        RUBY
      end

      def ruby_dev_desktop_flag_bootstrap
        <<~RUBY
          # ruflet_rails desktop flag
          if ARGV.delete("--desktop")
            ENV["RUFLET_RAILS_DESKTOP"] = "true"
            ENV["RUFLET_RAILS_DESKTOP_SERVER"] = "true"
          end

        RUBY
      end

      def shell_desktop_flag_bootstrap
        <<~SH
          # ruflet_rails desktop flag
          if [ "$1" = "--desktop" ]; then
            export RUFLET_RAILS_DESKTOP=true
            export RUFLET_RAILS_DESKTOP_SERVER=true
            shift
          fi

        SH
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

      def build_args_for_platform(platform, public_path: default_web_public_path)
        normalized = normalize_build_platform(platform)
        return [] if normalized.to_s.empty?

        args = [normalized]
        args += ["--base-href", web_base_href(public_path)] if normalized == "web"
        args
      end

      def default_entrypoint_path
        File.join("app", "views", "ruflet", "main.rb")
      end

      def route_snippet(entrypoint: default_entrypoint_path, mount_path: "/ws", helper: "app")
        %(match "#{mount_path}", to: Ruflet::Rails.#{helper}(Rails.root.join("#{entrypoint}")), via: :all)
      end

      def default_web_public_path
        normalize_web_public_path(ENV.fetch("RUFLET_RAILS_WEB_PATH", "app"))
      end

      def web_base_href(public_path = default_web_public_path)
        normalized = normalize_web_public_path(public_path)
        normalized.empty? ? "/" : "/#{normalized}/"
      end

      def normalize_web_public_path(path)
        path.to_s.strip.gsub(%r{\A/+|/+\z}, "")
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

        normalized_public_path = normalize_web_public_path(public_path)
        raise ArgumentError, "web public path cannot be / when publishing a Ruflet web client" if normalized_public_path.empty?

        target = File.join(root, "public", normalized_public_path)
        FileUtils.rm_rf(target)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp_r(source, target)
        rewrite_web_base_href(target, public_path: normalized_public_path)
        inject_web_client_bootstrap(target)
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

      def inject_web_client_bootstrap(target)
        index_path = File.join(target, "index.html")
        return unless File.file?(index_path)

        content = File.read(index_path)
        return if content.include?('id="ruflet-rails-bootstrap"')

        script = <<~HTML
          <script id="ruflet-rails-bootstrap">
            if (window.location.search === "" && window.location.hash === "") {
              const rufletServerUrl = window.location.origin + "/";
              window.history.replaceState(
                null,
                document.title,
                window.location.pathname + "?url=" + encodeURIComponent(rufletServerUrl)
              );
            }
          </script>
        HTML

        updated =
          if content.include?('<script src="flutter_bootstrap.js"')
            content.sub(%r{<script src="flutter_bootstrap\.js"[^>]*></script>}i) { |match| "#{script}  #{match}" }
          else
            content.sub(%r{</body>}i, "#{script}</body>")
          end
        File.write(index_path, updated)
      end

      def install_next_steps(target:, entrypoint:, client:, web_published:, mount_path: "/ws", web_path: default_web_public_path)
        web_path = normalize_web_public_path(web_path)
        display_web_path = web_base_href(web_path)
        lines = [
          "Ruflet Rails installed.",
          "Generated entrypoint: #{entrypoint}",
          "Mounted websocket: #{mount_path}",
          "Next steps:",
          "  1. Start Rails: bin/rails server",
          "  2. Open the Ruflet web client: #{display_web_path}"
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
            "Plain bin/dev, bin/rails server, and bin/rails s do not launch desktop.",
            "To launch desktop for a dev server run: bin/rails s --desktop or bin/dev --desktop",
            "To download the prebuilt desktop client: bin/rails ruflet:update[desktop]",
            "To build the host desktop client: bin/rails ruflet:build[desktop]"
          ]
        end

        lines
      end
    end
  end
end
