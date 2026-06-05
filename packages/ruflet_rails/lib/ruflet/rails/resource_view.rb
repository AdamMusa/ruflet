# frozen_string_literal: true

require "active_model"
require "active_support/core_ext/string/inflections"
require_relative "view"

module Ruflet
  module Rails
    class ResourceView < ::RufletView
      class << self
        def model(value = nil)
          @model_class = value if value
          @model_class || inferred_model_class
        end

        def title(value = nil)
          @resource_title = value if value
          @resource_title || model_name.plural.humanize.titleize
        end

        def component(value = nil)
          @component_class = value if value
          @component_class || inferred_component_class
        end

        private

        def inferred_model_class
          model_name.name.safe_constantize
        end

        def inferred_component_class
          "#{model_name.name}Component".safe_constantize
        end

        def model_name
          ActiveModel::Name.new(name.to_s.sub(/View\z/, "").singularize.constantize)
        rescue NameError
          ActiveModel::Name.new(Object, nil, name.to_s.sub(/View\z/, "").singularize)
        end
      end

      private

      def close_dialog(dialog)
        close_open_dialogs_above(dialog)
        close_tracked_dialog(dialog)
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

      def close_primary_dialog(dialog)
        page.update(dialog, open: false) if dialog.wire_id
      end

      def primary_dialog_slot?(dialog)
        page.instance_variable_defined?(:@dialog) && page.instance_variable_get(:@dialog).equal?(dialog)
      end
    end
  end
end
