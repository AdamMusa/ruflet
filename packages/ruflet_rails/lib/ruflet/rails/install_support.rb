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

      def scaffold_component_path(model_name)
        names = model_names(model_name)

        File.join("app", "views", "ruflet", "components", names[:plural], "#{names[:singular]}_component.rb")
      end

      # A `case` with no `when` clause is a syntax error, so models without
      # date/time attributes get the plain fallback body instead.
      def scaffold_display_value_body(display_value_cases, indent)
        return "#{indent}record.public_send(field).to_s" if display_value_cases.to_s.strip.empty?

        reindented_cases = display_value_cases.gsub(/^    /, indent)
        <<~RUBY.chomp.gsub(/^/, indent).gsub(/^#{Regexp.escape(indent)}__CASES__$/, reindented_cases)
          case field
          __CASES__
          else
            record.public_send(field).to_s
          end
        RUBY
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

          # The model (#{model_class}) is inferred from the class name and the route
          # ("/#{names[:plural]}") is declared in config/routes.rb. This file is YOURS:
          # the whole CRUD UI (index table, detail screen, create/edit form) and the
          # database calls (#{model_class}#update, #destroy!, .new) are explicit below
          # so you can change the UI or logic however you like. The base class only
          # provides reusable helpers: record loading, field inference, dialog
          # open/close, the date/time picker value helpers, and refresh.
          #
          # The same component renders on web and on mobile/desktop.
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
                    horizontal_alignment: "stretch",
                    children: [
                      #{control_list}
                    ]
                  )
                ),
                actions: [
                  text_button(content: text("Cancel"), on_click: ->(_event) { close_dialog(dialog) }),
                  filled_button(content: text("Save"), on_click: ->(_event) {
                    # Persist with the model (this is your code — change it freely).
                    if record.update(attributes.call)
                      close_dialog(dialog)
                      refresh
                      show_snackbar("\#{singular_title} saved")
                    else
                      show_errors(record)
                    end
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
                  filled_button(content: text("Delete"), on_click: ->(_event) {
                    # Destroy with the model (this is your code — change it freely).
                    record.destroy!
                    close_dialog(dialog)
                    refresh
                    show_snackbar("\#{singular_title} deleted")
                  })
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
                    page.update(#{display_control}, value: date_display_value(#{control}.value))
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
                    page.update(#{display_control}, value: time_display_value(#{control}.value))
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
                      value: date_range_display_value(#{control}.start_value, #{control}.end_value)
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
            "!!#{control}.value"
          when "date"
            "#{control}.value.to_s.split(\"T\", 2).first"
          when "date_range", "daterange"
            "Range.new(Date.parse(#{control}.start_value.to_s), Date.parse(#{control}.end_value.to_s))"
          else
            "#{control}.value.to_s"
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
                    column(spacing: 8, horizontal_alignment: "stretch", children: ruflet_form_controls(fields)),
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

      def build_args_for_platform(platform, ruflet_url: nil)
        normalized = normalize_build_platform(platform)
        return [] if normalized.to_s.empty?

        args = [normalized]
        args += ["--dart-define", "RUFLET_URL=#{ruflet_url}"] if normalized == "web" && ruflet_url.to_s.strip != ""
        args
      end

      def default_entrypoint_path
        File.join("app", "views", "ruflet", "main.rb")
      end

      def initializer_template(entrypoint: default_entrypoint_path, ws_path: "/ws")
        <<~RUBY
          # frozen_string_literal: true

          Ruflet::Rails.configure do |config|
            # Ruflet app entry-point. Auto-mounts a WebSocket endpoint at ws_path —
            # no explicit route needed in config/routes.rb.
            config.app_file = Rails.root.join(#{entrypoint.inspect})

            # URL path the WebSocket endpoint listens on (default: "/ws").
            config.ws_path = #{ws_path.inspect}

            # Base URL the Flutter client uses to reach this Rails app. Always
            # required: it backs asset URLs (Ruflet::Rails.asset_url), the
            # build-time RUFLET_URL define, and the desktop launcher. At runtime
            # it can fall back to the connecting host, but a build has no request,
            # so set it here. Point it at a LAN IP (not localhost) to test on a
            # real device.
            config.backend_url = ENV.fetch("RUFLET_BACKEND_URL") do
              Rails.env.production? ? "https://example.com" : "http://localhost:3000"
            end

            # Directory the Flutter web build is served from. Defaults to
            # Rails.root/build/web (where `rake ruflet:build[web]` outputs).
            # Must stay OUTSIDE public/, or Rails would serve it statically and
            # expose the app at a path no route declares.
            # config.web_build_dir = Rails.root.join("build", "web")
          end
        RUBY
      end

      def initializer_path
        File.join("config", "initializers", "ruflet.rb")
      end

      # Kept for backward compatibility with apps that use manual mount.
      def route_snippet(entrypoint: default_entrypoint_path, mount_path: "/ws", helper: "app")
        %(match "#{mount_path}", to: Ruflet::Rails.#{helper}(Rails.root.join("#{entrypoint}")), via: :all)
      end

      def install_next_steps(target:, entrypoint:, client:, mount_path: "/ws")
        lines = [
          "Ruflet Rails installed.",
          "Generated entrypoint: #{entrypoint}",
          "Mounted websocket: #{mount_path}",
          "Next steps:",
          "  1. Start Rails: bin/rails server",
          "  2. Connect your Ruflet app to ws://localhost:3000#{mount_path}"
        ]

        if client.to_s == "desktop"
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
