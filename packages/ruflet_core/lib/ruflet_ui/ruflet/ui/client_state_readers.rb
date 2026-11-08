# frozen_string_literal: true

require_relative "control_factory"

module Ruflet
  module UI
    # Readers for the control state the user changes on the client, so code
    # can read it the way the control docs do: `event.control.value` in an
    # on_change / on_select handler, `field.value` or `toggle.value` later.
    #
    # When the user changes one of these, the Flutter client sends
    # update_control with the new value and then fires the event (the
    # renderer's updateProperties / writeBack call, then triggerEvent).
    # Page#apply_client_update stores it in the control's props, and
    # Page#dispatch_event also applies change/select values before the
    # handler runs. A reader returns that stored value: `props["value"]`.
    #
    # The list below is deliberately small: only the properties the Flutter
    # renderers (ruflet-engine, packages/ruflet/lib/src/controls) send back
    # from user interaction, and only on the Ruby classes that declare them.
    # Every other property is still read with `control.props["name"]`.
    #
    # Left out on purpose:
    # * `open`, written back when a dialog, sheet, snack bar, banner or picker
    #   closes. Every object already has a private Kernel#open, on CRuby and
    #   in the embedded VM; a public reader would replace it.
    # * Dropdown `text`: it would replace the private Kernel `text` DSL helper.
    # * Values the client writes on controls whose Ruby class declares no such
    #   property (CodeEditor, the color pickers, Video, Geolocator).
    # * Page, View and Window measurements (route, width, height, media,
    #   platform_brightness): `page.width` and friends already answer those.
    # * Properties the client never writes back (Radio `value`, IconButton
    #   `selected`, ProgressBar `value`, ...): their props only change when
    #   Ruby changes them.
    #
    # The readers are ordinary public methods, defined once when Ruflet loads
    # (see the end of ruflet_ui.rb), so CRuby and the embedded mruby VM
    # expose exactly the same ones, and respond_to?, method and public_send
    # change for these names on these classes only. There are no setters.
    #
    # An app's own method always wins over a reader, wherever the app puts it.
    # Apps on v0.0.23, where these reads raised, may already have added one
    # themselves, for example
    # `class Ruflet::Control; def value = props["value"]; end`. So:
    # * A reader is never defined over a method that already exists, public or
    #   private, on the class or any ancestor (Kernel included).
    # * Each class gets its readers from its own module, included into the
    #   class (ClientStateReaders::RufletComponentsSwitchControl and so on).
    #   A method the app defines on the class itself, in a subclass, on the
    #   object, or in a module it includes into the class later comes first
    #   in the lookup and wins as usual.
    # * A method the app defines further up after Ruflet has loaded (on
    #   Ruflet::Control, PlatformControl, a module included or prepended
    #   there, a framework module such as TextInputMethods, Object or Kernel),
    #   public or private, comes after the reader in the lookup. The reader
    #   checks for one on every call and hands the call to it with `super`,
    #   arguments and block included. It hands the call to method_missing the
    #   same way when the app added one (see app_method_missing?).
    # Only when there is no such method does the reader answer: with no
    # arguments it returns props[name]; with arguments it raises the
    # ArgumentError a zero-argument method raises.
    module ClientStateReaders
      # mruby's Module#method_defined? also counts private methods; CRuby's
      # counts public and protected ones only.
      METHOD_DEFINED_COUNTS_PRIVATE = Class.new {
        def probe; end
        private :probe
      }.method_defined?(:probe)

      class << self
        # The [class, name] pairs install! left out, or nil until it has run.
        # ruflet_ui.rb runs it when Ruflet loads, so this is [] in every app.
        attr_reader :skipped

        # [control class, [property, ...]] pairs, grouped by the client control
        # and the renderers that write the value back to Ruby.
        def table
          components = PlatformControlContracts::Components
          controls = Controls::RufletComponents

          [
            # checkbox_core.dart
            [components::CheckboxControl, %w[value]],
            [controls::CheckboxControl, %w[value]],
            [controls::CupertinoCheckboxControl, %w[value]],
            # switch_core.dart
            [components::SwitchControl, %w[value]],
            [controls::SwitchControl, %w[value]],
            [controls::CupertinoSwitchControl, %w[value]],
            # slider.dart, cupertino_slider.dart
            [components::SliderControl, %w[value]],
            [controls::SliderControl, %w[value]],
            [controls::CupertinoSliderControl, %w[value]],
            # material_range_slider.dart, cupertino_input_controls.dart
            [controls::RangeSliderControl, %w[start_value end_value]],
            # radio_group.dart
            [controls::RadioGroupControl, %w[value]],
            # textfield.dart, cupertino_textfield.dart
            [components::TextFieldControl, %w[value selection]],
            [controls::TextFieldControl, %w[value selection]],
            [controls::CupertinoTextFieldControl, %w[value selection]],
            # material_search_bar.dart, cupertino_input_controls.dart
            [controls::SearchBarControl, %w[value]],
            # material_auto_complete.dart, cupertino_input_controls.dart
            [controls::AutoCompleteControl, %w[value]],
            # material_dropdown.dart, material_dropdown_m2.dart, cupertino_input_controls.dart
            [components::DropdownControl, %w[value]],
            [controls::DropdownControl, %w[value]],
            [controls::Dropdown2Control, %w[value]],
            # date_picker.dart (value, entry_mode), material_date_picker.dart,
            # cupertino_date_picker.dart, cupertino_date_picker_dialog.dart
            [components::DatePickerControl, %w[value entry_mode]],
            [controls::DatePickerControl, %w[value entry_mode]],
            [controls::CupertinoDatePickerControl, %w[value]],
            # material_date_range_picker.dart, cupertino_input_controls.dart
            [controls::DateRangePickerControl, %w[start_value end_value]],
            # material_time_picker.dart (value, entry_mode), cupertino_input_controls.dart
            [controls::TimePickerControl, %w[value entry_mode]],
            # material_timer_picker.dart, cupertino_timer_picker.dart
            [components::TimerPickerControl, %w[value]],
            [controls::CupertinoTimerPickerControl, %w[value]],
            # material_picker.dart, cupertino_picker.dart
            [components::PickerControl, %w[selected_index]],
            [controls::CupertinoPickerControl, %w[selected_index]],
            # segmented_button.dart (selected, selected_index),
            # cupertino_segmented_button.dart, cupertino_sliding_segmented_button.dart
            [components::SegmentedButtonControl, %w[selected selected_index]],
            [controls::SegmentedButtonControl, %w[selected]],
            [controls::CupertinoSegmentedButtonControl, %w[selected_index]],
            [controls::CupertinoSlidingSegmentedButtonControl, %w[selected_index]],
            # material_chip.dart, cupertino_content_controls.dart
            [controls::ChipControl, %w[selected]],
            # material_expansion_tile.dart, cupertino_content_controls.dart
            [controls::ExpansionTileControl, %w[expanded]],
            # material_expansion_panel.dart, cupertino_content_controls.dart
            [controls::ExpansionPanelControl, %w[expanded]],
            # material_tabs.dart, cupertino_content_controls.dart
            [controls::TabsControl, %w[selected_index]],
            # material_navigation_bar.dart, cupertino_navigation_bar.dart
            [components::NavigationBarControl, %w[selected_index]],
            [controls::NavigationBarControl, %w[selected_index]],
            [controls::CupertinoNavigationBarControl, %w[selected_index]],
            # material_navigation_drawer.dart, cupertino_navigation_controls.dart
            [controls::NavigationDrawerControl, %w[selected_index]],
            # material_navigation_rail.dart, cupertino_navigation_controls.dart
            [controls::NavigationRailControl, %w[selected_index]],
            # page_view.dart
            [controls::PageViewControl, %w[selected_index]]
          ]
        end

        # Defines every reader in the table, once. ruflet_ui.rb calls it as its
        # last statement. Returns the [class, name] pairs it left out because
        # the class already had a method of that name; with the table above
        # that list is empty, which the tests check on CRuby and in the
        # embedded VM.
        def install!
          return @skipped unless @skipped.nil?

          @skipped = define_readers(table).freeze
        end

        # Gives each class a reader module with a reader for each of its names,
        # except names the class already has a method for, public or private,
        # on itself or any ancestor. Returns the [class, name] pairs it skipped.
        # install! calls it with the table; the tests call it with their own
        # classes to check the guard.
        def define_readers(pairs)
          @ruflet_method_missing ||= Kernel.instance_method(:method_missing)
          @method_of ||= Kernel.instance_method(:method)
          skipped = []
          pairs.each do |klass, names|
            free = []
            names.each do |name|
              if any_method?(klass, name.to_sym)
                skipped << [klass, name]
              else
                free << name.to_s
              end
            end
            include_readers(klass, free) unless free.empty?
          end
          skipped
        end

        # Every reader asks this first. `after` is what comes after the reader
        # module in the class's lookup: the modules the class included before
        # it, then the superclass and everything above it, up to Object,
        # Kernel and BasicObject. True when any of them now has a method of
        # this name, public, protected or private: the method `super` calls,
        # and the one a call reached before the reader existed. Private ones
        # count too (a top-level `def value` in a script is a private Object
        # method), so a call from inside the control's own methods
        # (`value` with no receiver) still reaches them.
        def app_method_after?(after, symbol)
          after.any? { |mod| any_method?(mod, symbol) }
        end

        # Every reader asks this second. True when the control answers
        # method_missing with something other than Ruflet's own
        # Kernel#method_missing (ruflet_ui.rb, defined just before install!
        # runs): one the app added on the object, a control class, a
        # subclass, Object, a module in between, or in place of Ruflet's on
        # Kernel. Before the reader existed, that method_missing answered
        # `control.value`. Kernel#method is used unbound, so a control that
        # has a `method` of its own cannot change the answer. Only the owner
        # is compared for the control's method, and only Kernel's own two
        # UnboundMethods with ==: what == says about a method taken from an
        # object differs between Ruby versions.
        def app_method_missing?(control)
          !@method_of.bind_call(control, :method_missing).owner.equal?(Kernel) ||
            Kernel.instance_method(:method_missing) != @ruflet_method_missing
        end

        private

        # Public, protected or private, on the module or anything it includes
        # or inherits. mruby's method_defined? already counts private methods,
        # and its private_method_defined? (a bootstrap.rb fallback) lists every
        # method each call, so it is only asked on CRuby.
        def any_method?(mod, symbol)
          return true if mod.method_defined?(symbol)

          !METHOD_DEFINED_COUNTS_PRIVATE && mod.private_method_defined?(symbol)
        end

        def include_readers(klass, names)
          readers = Module.new
          name = reader_module_name(klass)
          const_set(name, readers) if name && !const_defined?(name, false)
          klass.send(:include, readers)

          ancestors = klass.ancestors
          after = ancestors[(ancestors.index(readers) + 1)...ancestors.index(klass.superclass)]
          after << klass.superclass
          after.freeze
          names.each { |reader| define_reader(readers, reader, after) }
          readers
        end

        # Ruflet::UI::Controls::RufletComponents::SwitchControl reads from
        # ClientStateReaders::RufletComponentsSwitchControl, and
        # PlatformControlContracts::Components::SwitchControl from
        # ClientStateReaders::ComponentsSwitchControl.
        def reader_module_name(klass)
          full = klass.name
          return nil unless full.is_a?(String) && !full.empty?

          full.split("::").last(2).join
        end

        # Arguments and a block go to the app's method unchanged. Without one,
        # a call with arguments raises what a zero-argument method raises on
        # CRuby and in the embedded VM alike, and a block is ignored, as any
        # Ruby reader ignores it.
        def define_reader(readers, name, after)
          key = name.to_s
          symbol = key.to_sym
          api = self
          readers.send(:define_method, symbol) do |*args, **options, &block|
            if api.app_method_after?(after, symbol)
              super(*args, **options, &block)
            elsif api.app_method_missing?(self)
              method_missing(symbol, *args, **options, &block)
            elsif args.empty? && options.empty?
              props[key]
            else
              given = args.length + (options.empty? ? 0 : 1)
              raise ArgumentError, "wrong number of arguments (given #{given}, expected 0)"
            end
          end
        end
      end
    end
  end
end
