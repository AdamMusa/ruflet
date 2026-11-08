# frozen_string_literal: true

module Ruflet
  class Page
    # The tables behind three Page decisions, kept appendable so a feature
    # adds its entries from its own file instead of editing Page's dispatch
    # code:
    #
    # * props: which page props travel on the Page control's patch (and
    #   which of those the page View mirrors) rather than on the View;
    # * events: which Page events Page#on subscribes the Page control to;
    # * methods: which control (the Page, or the top or root View) each
    #   Page method that calls the client invokes.
    #
    # Page seeds each table with what it handled before the tables existed
    # (see page.rb), so a table only changes behavior through an entry a
    # feature registers.
    #
    #   Ruflet::Page::Registry.register_prop("locale_configuration")
    #   Ruflet::Page::Registry.register_event("resize")
    #   Ruflet::Page::Registry.register_method("take_screenshot")
    #
    # Registration is meant for load time. Registering a name again with the
    # same options is a no-op; with different options it raises.
    module Registry
      METHOD_TARGETS = %i[page top_view root_view].freeze

      @props = {}
      @events = {}
      @methods = {}

      class << self
        # Routes the page prop +key+ to the Page control's patch: page.key =,
        # page(key: ...), set_view_props and update(:page, key: ...) then set
        # it there instead of on the page View. With view: true the View gets
        # the value too (as vertical_alignment, horizontal_alignment and
        # scroll do, which lay out the View's body).
        def register_prop(key, view: false)
          name = key.to_s
          raise ArgumentError, "page prop name must not be empty" if name.empty?
          if name.start_with?("on_")
            raise ArgumentError, "#{name} is an event handler; register the event with register_event"
          end
          if Page::DIALOG_PROP_KEYS.include?(name)
            raise ArgumentError, "#{name} is a page dialog slot, not a page prop"
          end

          register(@props, name, view ? :page_and_view : :page, "page prop")
        end

        # Registers +name+ (with or without its on_ prefix) as a Page event:
        # page.on(name) { ... } then puts on_<name>: true on the Page
        # control's patch while a block is set, and clears it when on(name)
        # is called without one. page.on_<name> = ... already flags every
        # event that is not a View event on the Page, registered or not.
        # View events (the View's on_* keywords) keep their View flag.
        def register_event(name)
          event = name.to_s
          event = event[3..-1] if event.start_with?("on_")
          raise ArgumentError, "page event name must not be empty" if event.empty?

          register(@events, event, true, "page event")
        end

        # Registers the client method +name+ that a Page method invokes, and
        # the control that answers it: :page (the Page control, wire id 1),
        # :top_view (the top View, e.g. drawers) or :root_view (the first
        # View, e.g. scroll_to). Without explicit views both are the page's
        # implicit View.
        def register_method(name, target: :page)
          method = name.to_s
          raise ArgumentError, "page method name must not be empty" if method.empty?
          unless METHOD_TARGETS.include?(target)
            raise ArgumentError, "page method target must be one of #{METHOD_TARGETS.inspect}, not #{target.inspect}"
          end

          register(@methods, method, target, "page method")
        end

        # :page when +key+ goes on the Page control only, :page_and_view when
        # the View mirrors it, nil when it is a View prop. Keys are matched
        # exactly as given (page props are strings).
        def prop_target(key)
          @props[key]
        end

        # Whether Page#on subscribes the Page control to +name+.
        def event?(name)
          @events.key?(name)
        end

        # The target registered for the client method +name+, or nil.
        def method_target(name)
          @methods[name.to_s]
        end

        # Registered page props, in registration order.
        def prop_keys
          @props.keys.freeze
        end

        # Registered Page events, in registration order.
        def event_names
          @events.keys.freeze
        end

        # Registered client methods and their targets, in registration order.
        def page_methods
          @methods.dup.freeze
        end

        private

        def register(table, name, value, kind)
          if table.key?(name)
            return name if table[name] == value

            raise ArgumentError, "#{kind} #{name} is already registered as #{table[name].inspect}"
          end

          table[name] = value
          name
        end
      end
    end
  end
end
