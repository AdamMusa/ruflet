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
      def default_mobile_app_template(app_title:)
        default_app_template(app_title: app_title)
      end

      def scaffold_view_template(model_name:, attributes:)
        names = scaffold_names(model_name)
        attrs = Array(attributes).map { |field| normalize_scaffold_attribute(field) }.reject { |field| field[:name].empty? }
        attrs = [{ name: "name", type: "string" }] if attrs.empty?
        columns_literal = attrs.map { |field| field[:name].inspect }.join(", ")
        fields_literal = attrs.map { |field| scaffold_field_literal(field) }.join(", ")
        model_class = names[:class_name]
        title = names[:title]
        singular_title = names[:singular].humanize.titleize

        template = <<~RUBY
          # frozen_string_literal: true

          require "ruflet_rails"

          class #{model_class}View < RufletView
              route #{("/" + names[:plural]).inspect}

              def render(action: :index, record: nil)
                case action.to_sym
                when :index
                  index
                when :show
                  show(record)
                when :new
                  open_form_dialog(model_class.new, title: "New #{singular_title}")
                when :edit
                  open_form_dialog(record, title: "Edit #{singular_title}")
                else
                  index
                end
              end

              def index
                records = model_class.order(created_at: :desc).limit(50)

                page.title = #{title.inspect}
                page.add(
                  safe_area(
                    container(
                      expand: true,
                      padding: { left: 24, top: 16, right: 24, bottom: 24 },
                      content: column(
                        expand: true,
                        spacing: 16,
                        controls: [
                          row(
                            alignment: "spaceBetween",
                            vertical_alignment: "center",
                            controls: [
                              container(
                                expand: true,
                                content: text(#{title.inspect}, size: 24, weight: "bold")
                              ),
                              filled_button(
                                content: text("New #{singular_title}"),
                                on_click: ->(_e) { open_form_dialog(model_class.new, title: "New #{singular_title}") }
                              )
                            ]
                          ),
                          data_table(
                            table_columns,
                            rows: records.map { |record| table_row(record) },
                            column_spacing: 24,
                            horizontal_margin: 12,
                            show_bottom_border: true
                          )
                        ]
                      )
                    ),
                    expand: true
                  )
                )
                page.update
              end

              def show(record)
                record ||= model_class.first
                return index unless record

                page.title = "#{singular_title} ##\{record.id}"
                page.add(
                  safe_area(
                    container(
                      expand: true,
                      padding: { left: 24, top: 16, right: 24, bottom: 24 },
                      content: column(
                        expand: true,
                        spacing: 16,
                        controls: [
                          row(
                            alignment: "spaceBetween",
                            vertical_alignment: "center",
                            controls: [
                              container(
                                expand: true,
                                content: text("#{singular_title} ##\{record.id}", size: 24, weight: "bold")
                              ),
                              action_buttons(record)
                            ]
                          ),
                          column(
                            spacing: 8,
                            controls: columns.map do |name|
                              row(
                                controls: [
                                  text(name.humanize, weight: "bold", width: 140),
                                  text(record.public_send(name).to_s)
                                ]
                              )
                            end
                          )
                        ]
                      )
                    ),
                    expand: true
                  )
                )
                page.update
              end

              def open_form_dialog(record, title:)
                fields = form_fields.to_h do |field|
                  [field[:name], field_control(field, record)]
                end

                page.show_dialog(
                  alert_dialog(
                    modal: true,
                    scrollable: true,
                    title: text(title),
                    content: container(
                      width: dialog_width,
                      content: column(spacing: 8, controls: fields.values)
                    ),
                    actions: [
                      outlined_button(
                        content: text("Cancel"),
                        on_click: ->(_e) { page.pop_dialog }
                      ),
                      filled_button(
                        content: text(record.persisted? ? "Update #{singular_title}" : "Create #{singular_title}"),
                        on_click: ->(_e) { save(record, fields) }
                      )
                    ],
                    actions_alignment: "end"
                  )
                )
              end

              def field_control(field, record)
                name = field[:name]
                type = field[:type].to_s
                value = record.public_send(name)
                label = name.humanize

                case type
                when "association", "references", "belongs_to"
                  dropdown(
                    association_options(field),
                    value: value.to_s,
                    label: label
                  )
                when "boolean"
                  checkbox(label: label, value: !!value)
                when "date"
                  date_picker(value: date_value(value), field_label_text: label)
                when "datetime", "timestamp"
                  date_picker(value: date_value(value), field_label_text: label, help_text: label)
                when "time"
                  time_picker(value: value.respond_to?(:strftime) ? value.strftime("%H:%M") : value.to_s, help_text: label)
                when "integer", "float", "decimal"
                  text_field(value: value.to_s, label: label, keyboard_type: "number")
                when "text"
                  text_field(value: value.to_s, label: label, multiline: true, min_lines: 3)
                else
                  text_field(value: value.to_s, label: label)
                end
              end

              def dialog_width
                width = page.client_details["width"].to_f
                return 520 if width <= 0

                [[width - 64, 280].max, 520].min
              end

              def open_delete_dialog(record)
                page.show_dialog(
                  alert_dialog(
                    modal: true,
                    title: text("Delete #{singular_title}?"),
                    content: text("This action cannot be undone."),
                    actions: [
                      outlined_button(
                        content: text("Cancel"),
                        on_click: ->(_e) { page.pop_dialog }
                      ),
                      filled_button(
                        content: text("Delete"),
                        on_click: ->(_e) do
                          record.destroy
                          page.pop_dialog
                          index
                        end
                      )
                    ],
                    actions_alignment: "end"
                  )
                )
              end

              def save(record, fields)
                attributes = fields.to_h do |name, control|
                  field = form_fields.find { |candidate| candidate[:name] == name }
                  [name, control_value(control, field[:type])]
                end

                if record.update(attributes)
                  page.pop_dialog
                  index
                else
                  page.snack_bar = snack_bar(text(record.errors.full_messages.to_sentence))
                  page.update
                end
              end

              def table_columns
                columns.map { |name| data_column(name.humanize) } + [data_column("Actions")]
              end

              def table_row(record)
                data_row(
                  columns.map do |name|
                    data_cell(record.public_send(name).to_s, on_tap: ->(_e) { show(record) })
                  end + [
                    data_cell(action_buttons(record))
                  ]
                )
              end

              def action_buttons(record)
                row(
                  spacing: 4,
                  controls: [
                    outlined_button(
                      content: text("Show"),
                      on_click: ->(_e) { show(record) }
                    ),
                    outlined_button(
                      content: text("Edit"),
                      on_click: ->(_e) { open_form_dialog(record, title: "Edit #{singular_title}") }
                    ),
                    outlined_button(
                      content: text("Delete"),
                      on_click: ->(_e) { open_delete_dialog(record) }
                    )
                  ]
                )
              end

              def control_value(control, type)
                value = control.props["value"]
                return value if type.to_s == "boolean"
                return value if %w[association references belongs_to].include?(type.to_s)

                value.to_s
              end

              def association_options(field)
                model = association_model(field)
                return [] unless model.respond_to?(:all)

                model.all.map do |record|
                  dropdown_option(record.id.to_s, text: association_label(record))
                end
              end

              def association_model(field)
                class_name = field[:class_name] || field[:name].to_s.sub(/_id\\z/, "").camelize
                class_name.safe_constantize if class_name.respond_to?(:safe_constantize)
              end

              def association_label(record)
                return record.name.to_s if record.respond_to?(:name)
                return record.title.to_s if record.respond_to?(:title)

                record.to_s
              end

              def date_value(value)
                return nil if value.nil?
                return value.iso8601 if value.respond_to?(:iso8601)
                return value.to_date.iso8601 if value.respond_to?(:to_date)

                value.to_s
              end

              def columns
                [#{columns_literal}]
              end

              def form_fields
                [#{fields_literal}]
              end

              def model_class
                #{model_class}
              end
          end
        RUBY
        template.gsub(/^    /, "  ")
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

      def scaffold_view_path(model_name, target: "frontend")
        names = scaffold_names(model_name)
        app_target = normalize_scaffold_target(target)

        File.join("app", "views", app_target, names[:plural], "#{names[:plural]}_view.rb")
      end

      def form_view_path(model_name, target: "frontend")
        names = scaffold_names(model_name)
        app_target = normalize_scaffold_target(target)

        File.join("app", "views", app_target, names[:plural], "_form.rb")
      end

      def scaffold_entrypoint_require(model_name)
        names = scaffold_names(model_name)

        %(load File.expand_path("#{names[:plural]}/#{names[:plural]}_view.rb", __dir__))
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

          class #{model_class}Form < RufletView

              FIELDS = [#{fields_literal}].freeze

              def render(record:, title: nil, on_save: nil, on_cancel: nil)
                title ||= record.persisted? ? "Edit #{singular_title}" : "New #{singular_title}"
                fields = FIELDS.to_h { |field| [field[:name], field_control(field, record)] }

                column(
                  expand: true,
                  spacing: 12,
                  controls: [
                    text(title, size: 24, weight: "bold"),
                    column(spacing: 8, controls: fields.values),
                    row(
                      spacing: 8,
                      controls: [
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
                attributes = fields.to_h do |name, control|
                  field = FIELDS.find { |candidate| candidate[:name] == name }
                  [name, control_value(control, field[:type])]
                end

                if record.update(attributes)
                  on_save ? on_save.call(page, record) : record
                else
                  page.snack_bar = snack_bar(text(record.errors.full_messages.to_sentence))
                  page.update
                  false
                end
              end

              def field_control(field, record)
                name = field[:name]
                type = field[:type].to_s
                value = record.public_send(name)
                label = name.humanize

                case type
                when "association", "references", "belongs_to"
                  dropdown(
                    association_options(field),
                    value: value.to_s,
                    label: label
                  )
                when "boolean"
                  checkbox(label: label, value: !!value)
                when "date"
                  date_picker(value: date_value(value), field_label_text: label)
                when "datetime", "timestamp"
                  date_picker(value: date_value(value), field_label_text: label, help_text: label)
                when "time"
                  time_picker(value: value.respond_to?(:strftime) ? value.strftime("%H:%M") : value.to_s, help_text: label)
                when "integer", "float", "decimal"
                  text_field(value: value.to_s, label: label, keyboard_type: "number")
                when "text"
                  text_field(value: value.to_s, label: label, multiline: true, min_lines: 3)
                else
                  text_field(value: value.to_s, label: label)
                end
              end

              def control_value(control, type)
                value = control.props["value"]
                return value if type.to_s == "boolean"
                return value if %w[association references belongs_to].include?(type.to_s)

                value.to_s
              end

              def association_options(field)
                model = association_model(field)
                return [] unless model.respond_to?(:all)

                model.all.map do |record|
                  dropdown_option(record.id.to_s, text: association_label(record))
                end
              end

              def association_model(field)
                class_name = field[:class_name] || field[:name].to_s.sub(/_id\\z/, "").camelize
                class_name.safe_constantize if class_name.respond_to?(:safe_constantize)
              end

              def association_label(record)
                return record.name.to_s if record.respond_to?(:name)
                return record.title.to_s if record.respond_to?(:title)

                record.to_s
              end

              def date_value(value)
                return nil if value.nil?
                return value.iso8601 if value.respond_to?(:iso8601)
                return value.to_date.iso8601 if value.respond_to?(:to_date)

                value.to_s
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

      def normalize_scaffold_target(target)
        value = target.to_s.strip.downcase.gsub(/[^a-z0-9_]/, "")
        value.empty? ? "frontend" : value
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

      def default_entrypoint_path(target: "frontend")
        File.join("app", "views", normalize_scaffold_target(target), "main.rb")
      end

      def route_snippet(entrypoint: default_entrypoint_path, mount_path: "/ws", helper: "app")
        %(mount Ruflet::Rails.#{helper}(Rails.root.join("#{entrypoint}")), at: "#{mount_path}")
      end

      def default_web_public_path
        "ruflet"
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
        true
      end
    end
  end
end
