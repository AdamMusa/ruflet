# frozen_string_literal: true

require_relative "scrollable_methods"

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Groups input fields that validate, reset and save together (Flutter's
        # Form). It lays out its `controls` like a Column (spacing, alignment,
        # scroll) and the client keeps Tab traversal inside it in order. The
        # validation itself runs in Ruby, where the validators live:
        #
        #   signup = form(on_submit: ->(e) { create_account(e.control.save) if e.control.validate }) do
        #     text_field(label: "Email", key: "email",
        #                validator: ->(v) { "Required" if v.empty? })
        #     checkbox(label: "I agree", key: "terms",
        #              validator: ->(v) { "Please accept" unless v })
        #   end
        #   signup.validate  # => false, errors shown on the fields
        #   signup.values    # => { "email" => "", "terms" => false }
        #   signup.reset     # back to the values the fields were mounted with
        #
        # Its fields are the inputs anywhere below it (Ruflet::FormFields)
        # that are not inside a nested form. A field takes part while it and
        # its ancestors up to the form are visible; validate also skips
        # disabled ones.
        #
        # autovalidate_mode (on the form or a field) follows Flutter:
        # "always" validates on every page update (and on any field change),
        # "on_user_interaction" once the user changed the field (on the form:
        # any field) until the next reset, "on_unfocus" when the field loses
        # focus. The form asks the client for the change/blur/submit events it
        # needs by setting the fields' on_* flags.
        class FormControl < Ruflet::Control
          include ScrollableMethods

          TYPE = "form".freeze
          WIRE = "Form".freeze

          KEYWORDS = [:align, :alignment, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :auto_scroll, :badge, :bottom, :col, :controls, :data, :disabled, :expand, :expand_loose, :height, :horizontal_alignment, :intrinsic_width, :key, :keyboard_dismiss_behavior, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :scale, :scroll, :scroll_interval, :size_change_interval, :spacing, :tight, :tooltip, :top, :visible, :width, :on_animation_end, :on_change, :on_scroll, :on_size_change, :on_submit].freeze

          REBUILD_MODES = %w[always on_user_interaction].freeze

          def initialize(id: nil, **props)
            form_options = FormFields.extract_options!(props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?

            super(type: TYPE, id: id, **props.reject { |_key, value| value.nil? })
            @entries = []
            @linked = {}
            @radio_groups = {}
            @initial_values = {}
            @interacted = {}
            @added_flags = {}
            apply_form_options!(form_options) unless form_options.empty?
          end

          # The fields of this form, in tree order.
          def fields
            link_fields!
            @entries.map(&:first)
          end

          # Runs the validator of every visible, enabled field on its current
          # value, shows each result on the field (an error, or none) and
          # pushes one page update. True when every field is valid.
          def validate
            link_fields!
            valid = true
            @entries.each do |field, visible, enabled|
              if visible && enabled
                valid = validate_field(field) && valid
              else
                clear_error(field)
              end
            end
            push_update
            valid
          end

          # Puts every field back to its value when it joined the form (when
          # the form was mounted or first used), clears the errors and the
          # "user interacted" state, and pushes one page update.
          def reset
            link_fields!
            @entries.each do |field, _visible, _enabled|
              FormFields.write_value(field, FormFields.copy(@initial_values[field.object_id]))
              clear_error(field)
            end
            @interacted.clear
            push_update
            self
          end

          # Calls on_saved with its value for every visible field that has
          # one. Returns form.values.
          def save
            link_fields!
            @entries.each do |field, visible, _enabled|
              next unless visible && field.on_saved

              field.on_saved.call(FormFields.value_of(field))
            end
            values
          end

          # { key => value } for every visible field: the field's `key`, or
          # its id when it has none.
          def values
            link_fields!
            @entries.each_with_object({}) do |(field, visible, _enabled), result|
              result[FormFields.key_of(field)] = FormFields.value_of(field) if visible
            end
          end

          # { key => message } for the visible fields whose last validation
          # failed.
          def errors
            link_fields!
            @entries.each_with_object({}) do |(field, visible, _enabled), result|
              next unless visible && field.validation_error

              result[FormFields.key_of(field)] = field.validation_error
            end
          end

          # Called by the page whenever it (re)registers the form, i.e. before
          # any patch that can carry it: links the fields and runs the
          # autovalidation a Flutter Form runs when it rebuilds.
          def sync_form_fields!
            link_fields!
            @entries.each do |field, visible, enabled|
              next unless visible && enabled && rebuild_validates?(field)

              validate_field(field)
            end
            self
          end

          # Page#dispatch_event routes a field's events here after the field's
          # own handler ran.
          def handle_field_event(control, name, event)
            radio = @radio_groups[control.object_id]
            if radio
              field_blurred(radio.last) if name == "blur"
              return
            end
            return unless @linked.key?(control.object_id)

            if name == FormFields.change_event(control)
              field_changed(control, event)
            elsif name == "blur"
              field_blurred(control)
            elsif name == "submit" && FormFields.text_field?(control)
              emit("submit", form_event("submit", event))
            end
          end

          private

          def field_changed(field, event)
            @interacted[field.object_id] = true
            emit("change", form_event("change", event)) if has_handler?("change")
            # Like a Flutter Form after a field's didChange: the page update
            # re-registers the form, whose sync runs the autovalidation.
            push_update if rebuild_modes?
          end

          def rebuild_modes?
            REBUILD_MODES.include?(autovalidate_mode) ||
              @entries.any? { |field, _visible, _enabled| REBUILD_MODES.include?(field.autovalidate_mode) }
          end

          def field_blurred(field)
            return unless unfocus_validates?(field)

            validate_field(field)
            push_update
          end

          def form_event(name, event)
            Ruflet::Event.new(name: name, target: wire_id, raw_data: event.raw_data, page: event.page, control: self)
          end

          def validate_field(field)
            return true unless field.validator

            message = FormFields.run_validator(field)
            FormFields.show_error(field, message)
            message.nil?
          end

          def clear_error(field)
            FormFields.show_error(field, nil) if field.validator || field.validation_error
          end

          def push_update
            page = runtime_page
            page.update if page && wire_id
          end

          # Flutter: a Form in "always" (or "on_user_interaction" once any of
          # its fields changed) validates every field when it rebuilds; a field
          # validates itself in "always" or, once the user changed it, in
          # "on_user_interaction".
          def rebuild_validates?(field)
            case autovalidate_mode
            when "always" then return true
            when "on_user_interaction" then return true unless @interacted.empty?
            end
            case field.autovalidate_mode
            when "always" then true
            when "on_user_interaction" then @interacted.key?(field.object_id)
            else false
            end
          end

          def unfocus_validates?(field)
            return true if field.autovalidate_mode == "on_unfocus"

            autovalidate_mode == "on_unfocus" && field.autovalidate_mode != "always"
          end

          # Walks the subtree for fields (not into a field, nor into a nested
          # form, which owns its own), links them to this form, remembers the
          # value each had when it joined, and sets the event flags they need.
          def link_fields!
            entries = []
            collect_fields(self, props["visible"] != false, props["disabled"] != true, entries, {})
            linked = {}
            radio_groups = {}
            entries.each do |field, _visible, _enabled|
              id = field.object_id
              linked[id] = field
              field.form_owner = self
              @initial_values[id] = FormFields.copy(FormFields.value_of(field)) unless @initial_values.key?(id)
              radios_of(field).each { |radio| radio_groups[radio.object_id] = [radio, field] } if field.wire_type == "RadioGroup"
            end
            radio_groups.each_value { |radio, _group| radio.form_owner = self }

            # Fields that left the form: unlink them and take back the flags
            # this form added.
            @linked.each do |id, field|
              next if linked.key?(id)

              field.form_owner = nil if field.form_owner.equal?(self)
              @initial_values.delete(id)
              @interacted.delete(id)
              drop_flags(field)
            end
            @radio_groups.each do |id, (radio, _group)|
              next if radio_groups.key?(id)

              radio.form_owner = nil if radio.form_owner.equal?(self)
              drop_flags(radio)
            end

            @entries = entries
            @linked = linked
            @radio_groups = radio_groups
            sync_event_flags!
          end

          def collect_fields(control, visible, enabled, entries, visited)
            control.children.each { |child| collect_value(child, visible, enabled, entries, visited) }
            control.props.each_value { |value| collect_value(value, visible, enabled, entries, visited) }
          end

          def collect_value(value, visible, enabled, entries, visited)
            case value
            when Ruflet::Control
              return if visited.key?(value.object_id) || value.equal?(self)

              visited[value.object_id] = true
              return if FormFields.form?(value)

              visible &&= value.props["visible"] != false
              enabled &&= value.props["disabled"] != true
              if FormFields.field?(value)
                entries << [value, visible, enabled]
              else
                collect_fields(value, visible, enabled, entries, visited)
              end
            when Array
              value.each { |item| collect_value(item, visible, enabled, entries, visited) }
            when Hash
              value.each_value { |item| collect_value(item, visible, enabled, entries, visited) }
            end
          end

          # A RadioGroup has no focus of its own; its Radios' blur stands for
          # the group's (Flutter's onUnfocus wraps the field in a Focus).
          def radios_of(group)
            radios = []
            stack = group.children + group.props.values
            visited = {}
            until stack.empty?
              value = stack.shift
              case value
              when Ruflet::Control
                next if visited.key?(value.object_id) || FormFields.field?(value) || FormFields.form?(value)

                visited[value.object_id] = true
                if value.wire_type == "Radio"
                  radios << value
                else
                  stack.concat(value.children)
                  stack.concat(value.props.values)
                end
              when Array then stack.concat(value)
              when Hash then stack.concat(value.values)
              end
            end
            radios
          end

          # The client only sends events whose on_* flag is set. Ask for the
          # change, blur and submit events the form reacts to, and take a flag
          # back once nothing needs it (unless the app handles that event).
          def sync_event_flags!
            changes = has_handler?("change") || rebuild_modes?
            submits = has_handler?("submit")
            radio_blur = {}
            @entries.each do |field, _visible, _enabled|
              set_flag(field, FormFields.change_event(field), changes)
              blur = unfocus_validates?(field)
              if field.wire_type == "RadioGroup"
                radio_blur[field.object_id] = blur
              else
                set_flag(field, "blur", blur && FormFields.declares_event?(field, "blur"))
              end
              set_flag(field, "submit", submits && FormFields.text_field?(field))
            end
            @radio_groups.each_value do |radio, group|
              set_flag(radio, "blur", radio_blur[group.object_id] == true)
            end
          end

          def set_flag(control, event, needed)
            key = "on_#{event}"
            added = (@added_flags[control.object_id] ||= {})
            if needed
              return if control.props[key] == true

              control.props[key] = true
              added[event] = true
            elsif added.delete(event)
              control.props.delete(key) unless control.has_handler?(event)
            end
          end

          def drop_flags(control)
            added = @added_flags.delete(control.object_id)
            return unless added

            added.each_key do |event|
              control.props.delete("on_#{event}") unless control.has_handler?(event)
            end
          end
        end
      end
    end
  end
end
