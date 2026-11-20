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
    # handler runs. A reader returns that stored value, `props["value"]`,
    # exactly as props holds it: the wire value, normalized when it was set
    # (`dropdown(value: :apple).value` is "apple", a Date given to a date
    # picker reads back as a Ruflet::Protocol::DateTimeValue).
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
    # Apps on v0.0.23, where these reads raised, may already answer them
    # themselves, with a method such as
    # `class Ruflet::Control; def value = props["value"]; end` or with a
    # method_missing. Whatever answered a call on v0.0.23 still answers it,
    # except in the cases under "Not covered" below. So:
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
    #   arguments and block included. Without an app method_missing, that is
    #   new for calls that raised on v0.0.23: a call with a receiver
    #   (`control.value`, `public_send(:value)`) now reaches a private one,
    #   or a protected one below Object, where v0.0.23 raised "private method
    #   'value' called" or "protected method"; and a protected one on Object,
    #   Kernel or a module Object includes now also answers
    #   `public_send(:value)` and `control.value` from code whose self is not
    #   an Object (a method of a BasicObject subclass).
    # * When the app added a method_missing, in front of Ruflet's own
    #   Kernel#method_missing in the lookup, in place of it, or after it (in a
    #   module included into Kernel, or on BasicObject; see
    #   app_method_missing?), the reader hands the call to method_missing,
    #   arguments and block included, so it reaches the app's through
    #   Ruflet's Kernel#method_missing when the app's comes after it. It does
    #   not when the method after the reader is public, or protected on
    #   Object, Kernel or a module Object includes. That is what CRuby did
    #   without the reader for `control.value` from code whose self is an
    #   Object, as nearly every self is (a method of a BasicObject subclass
    #   is the exception): a call with a receiver goes to method_missing when
    #   the method is private, or protected and the caller is not an instance
    #   of the module that has it. (`public_send`, and a caller whose self is
    #   not an Object, went to the method_missing for such a protected
    #   method; see "Not covered".) The method
    #   after the reader is the one Ruby's lookup finds first, so a private
    #   Ruflet::Control#value hides a public Object#value, in the embedded VM
    #   too (see method_after). (mruby stopped a call with a receiver at
    #   Ruflet's private Kernel#method_missing and raised, so on v0.0.23 a
    #   method_missing after it answered no `control.value` there; the reader
    #   reaches it in the VM as on CRuby.) When the app's method_missing passes
    #   the call on with `super`, the error is the one CRuby raised for
    #   `control.value` without the reader, whatever missed earlier on the
    #   thread (see MISSED_CALL).
    # * The private Kernel DSL helper Ruflet::Extensions.register_control
    #   defines for an extension registered after Ruflet loaded (`expanded`,
    #   say) is Ruflet's, not the app's. A plain `tile.expanded` reads the
    #   state instead of building an `expanded` control (on v0.0.23 it
    #   raised); a call with arguments or a block still reaches the helper,
    #   unless the app has its own method_missing (see "Not covered"). Once
    #   the app makes the helper public or protected on Kernel, it is the
    #   app's: `tile.expanded` calls it, as on v0.0.23.
    #   (In the embedded mruby VM, registering an extension after Ruflet has
    #   loaded already raises TypeError, on v0.0.23 too, so this is CRuby's.)
    # Only when there is no such method does the reader answer: with no
    # arguments it returns props[name]; with arguments it raises the
    # ArgumentError a zero-argument method raises.
    #
    # Not covered, because a method cannot see how it was called:
    # * Refinements (CRuby only) of a class above the table class: the reader
    #   answers as if the refinement were not active.
    # * An app that has both its own method_missing and a private method of
    #   a reader's name above the table class (a top-level `def value` in a
    #   script, say), or a protected one below Object (on Ruflet::Control,
    #   say). The calls that reached that method on v0.0.23 from inside the
    #   control (no receiver, `self.value`, `send(:value)`), and protected
    #   calls from another control, now go to the method_missing. Ruflet's
    #   own extension helpers are such private methods:
    #   `expanded(content: ...)` in an ExpansionTile method goes to the
    #   method_missing too. Every other call with a receiver went to the
    #   method_missing on v0.0.23 under CRuby (mruby raised), and now goes
    #   there on both.
    # * The same app with a protected method of that name on Object, Kernel
    #   or a module Object includes: CRuby called it for `control.value` on
    #   v0.0.23 and the reader still does, but `public_send(:value)`, and
    #   `control.value` from code whose self is not an Object (a method of a
    #   BasicObject subclass), went to the method_missing and now reach the
    #   protected method too. (mruby raised "protected method called" for
    #   every such call with a receiver; it now reaches the protected method
    #   as well.)
    # * A plain call without a receiver to Ruflet's own extension helper, from
    #   inside a method of the table class (`expanded` in an ExpansionTile
    #   method), returns the reader's value, or the app's method_missing's
    #   answer if it has one; on v0.0.23 it built an empty `expanded`
    #   control.
    # * A call without a receiver (a bare `value` in a control method,
    #   `self.value`, `send(:value)`, `super` from a `value` an app subclass
    #   defines) that the app's method_missing passes to `super` raises what
    #   `control.value` raises on CRuby: NoMethodError "undefined method"
    #   with private_call? false. On v0.0.23 the bare word raised NameError
    #   "undefined local variable or method", `super` raised NoMethodError
    #   "super: no superclass method 'value'", and all but the bare word had
    #   private_call? true.
    module ClientStateReaders
      # mruby's Module#method_defined? also counts private methods; CRuby's
      # counts public and protected ones only. (Guarded so that loading this
      # file again, as a hot reload of a vendored framework does, adds no
      # warning.)
      unless const_defined?(:METHOD_DEFINED_COUNTS_PRIVATE, false)
        METHOD_DEFINED_COUNTS_PRIVATE = Class.new {
          def probe; end
          private :probe
        }.method_defined?(:probe)
      end

      # CRuby's method_defined?, public_method_defined? and
      # private_method_defined? take an inherit flag, and with false they
      # look at the module's own methods only. mruby's take no flag (the last
      # two are ruby_runtime/vm/bootstrap.rb fallbacks), so there own_method?
      # and own_public_method? read the module's own method lists instead.
      # (Guarded like the constant above.)
      unless const_defined?(:OWN_METHOD_PREDICATES, false)
        OWN_METHOD_PREDICATES = begin
          probe = Module.new
          probe.method_defined?(:probe, false)
          probe.public_method_defined?(:probe, false)
          probe.private_method_defined?(:probe, false)
          true
        rescue ArgumentError
          false
        end
      end

      # Ruby's own BasicObject#method_missing raises the error of the call
      # that missed, and on CRuby it reads how that call missed from the
      # thread's last method miss: a method that does not exist gives
      # NoMethodError "undefined method 'value' ...", a private one "private
      # method 'value' called ...", a bare word NameError "undefined local
      # variable or method 'value' ...". A reader that hands a call to an app
      # method_missing calls method_missing itself, which is not a miss, so
      # when the app's calls `super`, the error would describe whatever missed
      # last on the thread (a bare scoped helper such as `local_auth`, which
      # Ruflet's Kernel#method_missing answers, is such a miss). So the reader
      # first repeats, on MISSED_CALL, the miss `control.value` made before
      # the reader existed (see repeat_miss). MISSED_CALL's method_missing
      # answers that call with nil.
      #
      # REPEATS_MISS is false in the embedded VM: this mruby raises "private
      # method called" for a call with a receiver to a private method before
      # any method_missing runs, and its BasicObject#method_missing always
      # raises "undefined method", so there is nothing to repeat. The probe
      # runs in a Fiber of its own: CRuby keeps the last miss per Fiber, so
      # loading Ruflet leaves the caller's last miss as it was, whatever
      # missed before the require. (Both guarded like the constants above.)
      unless const_defined?(:MISSED_CALL, false)
        MISSED_CALL = Object.new
        class << MISSED_CALL
          def method_missing(_name, *_args)
            nil
          end

          def private_reader; end
          def protected_reader; end
          private :private_reader
          protected :protected_reader
        end
        MISSED_CALL.freeze
      end

      unless const_defined?(:REPEATS_MISS, false)
        REPEATS_MISS = Fiber.new do
          begin
            MISSED_CALL.private_reader
            true
          rescue NoMethodError
            false
          end
        end.resume
      end

      class << self
        # The [class, name] pairs install! left out, or nil until it has run.
        # ruflet_ui.rb runs it when Ruflet loads. It is [] unless the app
        # defined a method of one of these names before loading Ruflet (then
        # it lists those pairs, and the app's method answers).
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
        #
        # Every call records the method_missing definitions that are not the
        # app's (see app_method_missing?): Kernel#method_missing, which
        # ruflet_ui.rb has just defined, SharedControlForwarders#method_missing,
        # which it loaded earlier, and Ruby's own BasicObject#method_missing.
        # When the framework is loaded again (`ruflet run` hot reload
        # re-requires it when its sources sit inside the watched app
        # directory), Ruflet's two are defined again and ruflet_ui.rb calls
        # this again, so the readers keep answering instead of taking the new
        # definitions for an app's.
        def install!
          record_method_missing
          return @skipped unless @skipped.nil?

          @skipped = define_readers(table).freeze
        end

        # Gives each class a reader module with a reader for each of its names,
        # except names the class already has a method for, public or private,
        # on itself or any ancestor. Returns the [class, name] pairs it skipped.
        # install! calls it with the table; the tests call it with their own
        # classes to check the guard.
        def define_readers(pairs)
          record_method_missing unless @ruflet_method_missing
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
        # (`value` with no receiver) still reaches them, unless the app also
        # added a method_missing (see reachable_method_after?).
        def app_method_after?(after, symbol)
          after.any? { |mod| any_method?(mod, symbol) }
        end

        # Asked when app_method_after? and app_method_missing? are both true.
        # True when, without the reader, CRuby called the method `super`
        # would call for `control.value` from code whose self is an Object,
        # whatever method_missing the app had: a public method, or a protected
        # one of Object, Kernel or a module Object includes. CRuby lets a
        # caller whose self is an instance of the method's module call a
        # protected method with a receiver, and nearly every caller's self is
        # an Object (a method of a BasicObject subclass is the exception).
        # (`public_send`, and such a caller, went to the method_missing for
        # that protected method; the reader cannot see its caller and calls
        # the method for them too. See "Not covered".) A private method, or a
        # protected one further down (Ruflet::Control, PlatformControl, a
        # module the class includes), it reached only from inside the
        # control (no receiver, `self.`) or, if protected, from another
        # control; CRuby sent every other call with a receiver to
        # method_missing instead.
        # The visibility is the one the module that method_after finds gave
        # the method, as in Ruby's own lookup.
        def reachable_method_after?(after, symbol)
          owner = method_after(after, symbol)
          return false unless owner
          return true if own_public_method?(owner, symbol)

          !own_private_method?(owner, symbol) && Object.ancestors.include?(owner)
        end

        # Asked for a plain read (no arguments, no block) when
        # app_method_after? is true. True when the method `super` would call is
        # the private Kernel DSL helper Ruflet::Extensions.register_control
        # defined for an extension of this name, unchanged and still private:
        # Ruflet's helper, not an app method. Without the reader,
        # `tile.expanded` raised ("private method 'expanded' called"), so the
        # reader answers instead of building an `expanded` control. Once the
        # app has made the helper public or protected on Kernel
        # (`module Kernel; public :expanded; end`), `tile.expanded` called it
        # on v0.0.23, so it counts as the app's and still answers. Only
        # Kernel's own two UnboundMethods are compared with ==: == does not
        # look at visibility.
        def ruflet_helper_after?(after, symbol)
          helper = Ruflet::Extensions.kernel_helper(symbol)
          return false unless helper

          method_after(after, symbol).equal?(Kernel) && own_private_method?(Kernel, symbol) &&
            Kernel.instance_method(symbol) == helper
        end

        # The module whose method of this name `super` would call from the
        # reader, or nil: in the lookup after the reader module, the first
        # module that has a method of this name itself, public, protected or
        # private. A visibility change (`private :value` in a class that
        # inherits `value`) is such a method of that class, as in Ruby's
        # lookup. register_control's Kernel helper is one too (Kernel makes
        # the SharedControlForwarders method private), which is why
        # UnboundMethod#owner is not used here: for such a method it is the
        # module that made the change on Ruby 3.2 and later, but the module
        # that defined the method on Ruby 3.1 (Ruby bug #18729). And
        # public_method_defined? is not asked of the module that inherits the
        # method: mruby's (a bootstrap.rb fallback) lists public methods
        # without letting a private one of the same name hide them.
        def method_after(after, symbol)
          mod = after.find { |candidate| any_method?(candidate, symbol) }
          mod && mod.ancestors.find { |ancestor| own_method?(ancestor, symbol) }
        end

        # Every reader asks this too. True when an app method_missing answers
        # a call that reaches method_missing on the control, as one answered
        # `control.value` before the reader existed. Ruflet's own definitions
        # and Ruby's are not the app's (see record_method_missing). The app's
        # can come first in the lookup: on the object, a control class, a
        # subclass, Object, a module in between, or in place of Ruflet's on
        # Kernel. Or it can come after Ruflet's Kernel#method_missing
        # (app_method_missing_after_kernel?).
        #
        # Kernel#method is used unbound, so a control that has a `method` of
        # its own cannot change the answer. Only the owner is compared for the
        # control's method, and the modules' own UnboundMethods with ==: what
        # == says about a method taken from an object differs between Ruby
        # versions. The owner differs for one thing: a class that only changes
        # the visibility of method_missing (`public :method_missing`) is its
        # owner on Ruby 3.2 and later, so it counts as an app method_missing
        # there, and not on Ruby 3.1. A read raised NoMethodError in such an
        # app on v0.0.23; on 3.2 and later it still does, on 3.1 the reader
        # answers.
        def app_method_missing?(control)
          return true unless @method_of.bind_call(control, :method_missing).owner.equal?(Kernel)
          return true unless Kernel.instance_method(:method_missing) == @ruflet_method_missing

          app_method_missing_after_kernel?
        end

        # A reader calls this just before it hands a call to an app
        # method_missing (see MISSED_CALL). It repeats the miss CRuby made
        # for `control.value` before the reader existed: of a private method
        # when the method `super` would call is private (a top-level `def
        # value`, Ruflet's own extension helper), of a protected one when it
        # is protected (on Ruflet::Control, say; a public one, or a protected
        # one on Object, Kernel or a module Object includes, gets the call
        # instead), and of a method that does not exist when there is none.
        def repeat_miss(after, symbol)
          return unless REPEATS_MISS

          owner = method_after(after, symbol)
          if owner && own_private_method?(owner, symbol)
            MISSED_CALL.private_reader
          elsif owner
            MISSED_CALL.protected_reader
          else
            MISSED_CALL.undefined_reader
          end
          nil
        end

        private

        # Asked when the first method_missing in the lookup is Ruflet's
        # Kernel#method_missing. For a call with no arguments and no block it
        # calls `super` at once, and so does
        # SharedControlForwarders#method_missing, which Kernel includes. So on
        # v0.0.23 `control.value` reached the next method_missing after them:
        # one in a module the app included into Kernel (it comes after
        # SharedControlForwarders when it was included before Ruflet loaded,
        # in front of it when included later), one the app defined on
        # BasicObject in place of Ruby's own, or one in a module prepended to
        # BasicObject. True when there is such a method_missing. The walk
        # stops at Ruby's own BasicObject#method_missing: it raises
        # NoMethodError and calls nothing after it, so a module included into
        # BasicObject was never reached.
        def app_method_missing_after_kernel?
          kernel = Kernel.ancestors
          chain = kernel.drop(kernel.index(Kernel) + 1).concat(BasicObject.ancestors)
          chain.each do |mod|
            next unless any_method?(mod, :method_missing)

            found = mod.instance_method(:method_missing)
            owner = found.owner
            if owner.equal?(SharedControlForwarders)
              return true unless found == @forwarders_method_missing
            else
              return !owner.equal?(BasicObject) || found != @ruby_method_missing
            end
          end
          false
        end

        # What install! records: Ruflet's Kernel#method_missing and
        # SharedControlForwarders#method_missing, and Ruby's own
        # BasicObject#method_missing, or nil when BasicObject's is already the
        # app's (defined before Ruflet loaded). Each is taken from its module,
        # as app_method_missing? takes it, so == compares the definitions.
        # Ruby's is built in: on CRuby and in the embedded VM it has no
        # source_location and its parameters have no names. One written in
        # Ruby has a source_location on CRuby, and named parameters in the
        # embedded VM (where Ruflet's compiled framework has no
        # source_location either).
        def record_method_missing
          @ruflet_method_missing = Kernel.instance_method(:method_missing)
          @forwarders_method_missing = SharedControlForwarders.instance_method(:method_missing)
          ruby = any_method?(BasicObject, :method_missing) && BasicObject.instance_method(:method_missing)
          built_in = ruby && ruby.source_location.nil? && ruby.parameters.all? { |_kind, name| name.nil? }
          @ruby_method_missing = built_in ? ruby : nil
        end

        # Public, protected or private, on the module or anything it includes
        # or inherits. mruby's method_defined? already counts private methods,
        # and its private_method_defined? (a bootstrap.rb fallback) lists every
        # method each call, so it is only asked on CRuby.
        def any_method?(mod, symbol)
          return true if mod.method_defined?(symbol)

          !METHOD_DEFINED_COUNTS_PRIVATE && mod.private_method_defined?(symbol)
        end

        # Public, protected or private, on the module itself only.
        def own_method?(mod, symbol)
          if OWN_METHOD_PREDICATES
            mod.method_defined?(symbol, false) || mod.private_method_defined?(symbol, false)
          else
            mod.instance_methods(false).include?(symbol) || mod.private_instance_methods(false).include?(symbol)
          end
        end

        # Public, on the module itself (see method_after).
        def own_public_method?(mod, symbol)
          if OWN_METHOD_PREDICATES
            mod.public_method_defined?(symbol, false)
          else
            mod.public_instance_methods(false).include?(symbol)
          end
        end

        # Private, on the module itself (see method_after).
        def own_private_method?(mod, symbol)
          if OWN_METHOD_PREDICATES
            mod.private_method_defined?(symbol, false)
          else
            mod.private_instance_methods(false).include?(symbol)
          end
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

        # In order: a method after the reader module (see the module comment),
        # unless it is an app method_missing's turn or Ruflet's own extension
        # helper on a plain read; then the app's method_missing, after
        # repeat_miss; then the reader itself. Arguments, keyword arguments
        # and a block go to the app's method or method_missing unchanged.
        # Without one, a call with arguments raises what a zero-argument
        # method raises on CRuby and in the embedded VM alike, and a block is
        # ignored, as any Ruby reader ignores it.
        def define_reader(readers, name, after)
          key = name.to_s
          symbol = key.to_sym
          api = self
          readers.send(:define_method, symbol) do |*args, **options, &block|
            plain = args.empty? && options.empty?
            found = api.app_method_after?(after, symbol) &&
                    !(plain && block.nil? && api.ruflet_helper_after?(after, symbol))
            answering = api.app_method_missing?(self)
            if found && (!answering || api.reachable_method_after?(after, symbol))
              super(*args, **options, &block)
            elsif answering
              api.repeat_miss(after, symbol)
              method_missing(symbol, *args, **options, &block)
            elsif plain
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
