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
    # change for these names on these classes only. A reader is never defined
    # over an existing method, public or private, of the class or any
    # ancestor. A reader takes no arguments; there are no setters.
    module ClientStateReaders
      class << self
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

        # Defines every reader in the table, once. Returns the [class, name]
        # pairs it left out because the class already had a method of that
        # name; with the table above that list is empty, which the tests check
        # on CRuby and in the embedded VM.
        def install!
          return @skipped unless @skipped.nil?

          @skipped = define_readers(table).freeze
        end

        # Defines a reader for each name on its class, unless the class already
        # has a method of that name (see method_exists?). Returns the
        # [class, name] pairs it skipped. install! calls it with the table;
        # the tests call it with their own classes to check the guard.
        def define_readers(pairs)
          skipped = []
          pairs.each do |klass, names|
            names.each do |name|
              skipped << [klass, name] unless define_reader(klass, name)
            end
          end
          skipped
        end

        private

        # Public, private or protected, on the class or any ancestor (Kernel
        # included). CRuby's method_defined? counts public and protected
        # methods only; mruby's also counts private ones. The respond_to?
        # guard keeps an mruby build without private_method_defined? working.
        def method_exists?(klass, name)
          symbol = name.to_sym
          return true if klass.method_defined?(symbol)

          klass.respond_to?(:private_method_defined?) && klass.private_method_defined?(symbol)
        end

        # A plain zero-argument method. define_method checks the block's arity
        # on CRuby and in the embedded mruby VM alike, so `control.value(1)`
        # raises the same ArgumentError on both. Like any Ruby reader it
        # ignores a block.
        def define_reader(klass, name)
          return false if method_exists?(klass, name)

          key = name.to_s
          klass.send(:define_method, key.to_sym) { props[key] }
          true
        end
      end
    end
  end
end
