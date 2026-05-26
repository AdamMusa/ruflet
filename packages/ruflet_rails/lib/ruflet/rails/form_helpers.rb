# frozen_string_literal: true

module Ruflet
  module Rails
    module FormHelpers
      def ruflet_form_bindings(record, form_fields)
        form_fields.to_h do |field|
          [field[:name], ruflet_field_binding(field, record)]
        end
      end

      def ruflet_form_controls(bindings)
        bindings.values.map { |binding| binding[:control] }
      end

      def ruflet_form_attributes(bindings, form_fields)
        bindings.to_h do |name, binding|
          field = form_fields.find { |candidate| candidate[:name] == name }
          control = binding[:input] || binding[:control] || binding
          [name, ruflet_control_value(control, field[:type])]
        end
      end

      def ruflet_show_errors(record)
        ruflet_show_snackbar(ruflet_error_message(record))
      end

      def ruflet_show_snackbar(message)
        page.snackbar = snackbar(text(message), open: true)
      end

      private

      def ruflet_field_binding(field, record)
        type = field[:type].to_s
        return ruflet_picker_field_binding(field, record) if %w[date datetime timestamp time].include?(type)

        control = ruflet_field_control(field, record)
        { control: control, input: control }
      end

      def ruflet_field_control(field, record)
        name = field[:name]
        type = field[:type].to_s
        value = record.public_send(name)
        label = name.humanize

        case type
        when "association", "references", "belongs_to"
          dropdown(
            ruflet_association_options(field),
            value: value.to_s,
            label: label
          )
        when "boolean"
          checkbox(label: label, value: !!value)
        when "integer", "float", "decimal"
          text_field(value: value.to_s, label: label, keyboard_type: "number")
        when "text"
          text_field(value: value.to_s, label: label, multiline: true, min_lines: 3)
        else
          text_field(value: value.to_s, label: label)
        end
      end

      def ruflet_picker_field_binding(field, record)
        name = field[:name]
        type = field[:type].to_s
        value = record.public_send(name)
        label = name.humanize
        picker = ruflet_picker_control(type, value, label)
        display = text(ruflet_picker_display_text(label, picker.props["value"]))

        picker.on(:change) do |event|
          page.update(event.control, open: false)
          page.update(display, value: ruflet_picker_display_text(label, event.control.props["value"]))
        end
        picker.on(:dismiss) { |event| page.update(event.control, open: false) }

        {
          control: column(
            spacing: 6,
            controls: [
              display,
              outlined_button(
                content: text("Choose #{label}"),
                on_click: ->(_e) { page.update(picker, open: true) }
              ),
              picker
            ]
          ),
          input: picker
        }
      end

      def ruflet_picker_control(type, value, label)
        case type
        when "time"
          time_picker(value: value.respond_to?(:strftime) ? value.strftime("%H:%M") : value.to_s, help_text: label, open: false)
        when "datetime", "timestamp"
          date_picker(value: ruflet_date_value(value), help_text: label, open: false)
        else
          date_picker(value: ruflet_date_value(value), help_text: label, open: false)
        end
      end

      def ruflet_control_value(control, type)
        value = control.props["value"]
        return nil if value.to_s.empty?
        return value if type.to_s == "boolean"
        return value if %w[association references belongs_to].include?(type.to_s)
        return value.to_s.split("T", 2).first if type.to_s == "date"
        return value.to_s if %w[datetime timestamp time].include?(type.to_s)

        value.to_s
      end

      def ruflet_association_options(field)
        model = ruflet_association_model(field)
        return [] unless model.respond_to?(:all)

        model.all.map do |record|
          dropdown_option(record.id.to_s, text: ruflet_association_label(record))
        end
      end

      def ruflet_association_model(field)
        class_name = field[:class_name] || field[:name].to_s.sub(/_id\z/, "").camelize
        class_name.safe_constantize if class_name.respond_to?(:safe_constantize)
      end

      def ruflet_association_label(record)
        return record.name.to_s if record.respond_to?(:name)
        return record.title.to_s if record.respond_to?(:title)

        record.to_s
      end

      def ruflet_date_value(value)
        return nil if value.nil?
        return value.iso8601 if value.respond_to?(:iso8601)
        return value.to_date.iso8601 if value.respond_to?(:to_date)

        value.to_s
      end

      def ruflet_picker_display_text(label, value)
        visible = value.to_s.empty? ? "Not selected" : value.to_s.split("T", 2).first
        "#{label}: #{visible}"
      end

      def ruflet_error_message(record)
        messages = record.errors.full_messages
        messages.respond_to?(:to_sentence) ? messages.to_sentence : messages.join(", ")
      end
    end
  end
end
