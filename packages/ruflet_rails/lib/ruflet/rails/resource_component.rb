# frozen_string_literal: true

require "date"
require "time"

module Ruflet
  module Rails
    class ResourceComponent
      include Ruflet::UI::SharedControlForwarders

      attr_reader :page, :controller

      def initialize(page, controller:)
        @page = page
        @controller = controller
      end

      private

      def control_delegate
        Ruflet::DSL
      end

      def open_dialog(dialog)
        prune_closed_dialogs
        return open_primary_dialog(dialog) if primary_dialog?(dialog) && !latest_stack_dialog

        preserve_rendered_open_dialog_state
        page.show_dialog(dialog)
        dialog
      end

      def close_dialog(dialog)
        close_tracked_dialog(dialog)
      end

      def close_dialogs(*dialogs)
        dialogs.flatten.compact.each do |dialog|
          remove_tracked_dialog(dialog)
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

      def close_tracked_dialog(dialog)
        return unless dialog

        close_dialog_stack_entry(dialog)
      end

      def remove_tracked_dialog(dialog)
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

      def method_missing(name, *args, **kwargs, &block)
        return controller.__send__(name, *args, **kwargs, &block) if controller.respond_to?(name, true)

        super
      end

      def respond_to_missing?(name, include_private = false)
        controller.respond_to?(name, true) || super
      end
    end
  end
end
