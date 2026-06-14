# frozen_string_literal: true

require "date"
require "time"
require "active_model"
require "active_support/core_ext/string/inflections"

module Ruflet
  module Rails
    # Base class for a Ruflet CRUD resource.
    #
    # The generated subclass owns the explicit CRUD UI (render, show, the
    # create/edit form) AND the database calls (record.update, record.destroy!,
    # model_class.new) — so a developer can read and change anything. This base
    # provides reusable helpers: model resolution, record loading,
    # field inference (resource_fields/display_fields/display_value), navigation
    # (render_index/render_show/refresh), dialog management, snackbars, and the
    # date/time picker value helpers.
    #
    # The same subclass renders on web and on mobile/desktop. It is mounted from
    # config/routes.rb (the route path is declared there, never in the
    # component):
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

      # Fields rendered on the detail (show) screen. The default uses the
      # model's own attribute names; subclasses can override it.
      def resource_fields
        default_resource_fields
      end

      # Columns rendered in the index table / list tiles.
      def display_fields
        resource_fields
      end

      # Formats a single field for display. Override for custom rendering.
      def display_value(record, field)
        record.public_send(field).to_s
      end

      # --- Record loading & navigation ---------------------------------------

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

      # Re-render the index after a create/update/destroy. The generated
      # component calls this from its own (explicit) save/destroy code.
      def refresh
        render_index
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

      def default_resource_fields
        return [] unless model_class.respond_to?(:attribute_names)

        ignored = %w[id created_at updated_at]
        model_class.attribute_names.map(&:to_s) - ignored
      rescue StandardError
        []
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
